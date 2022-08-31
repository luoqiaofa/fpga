/*
 * Freescale eSPI controller driver.
 *
 * Copyright 2022 HuaZhen Info ltd, Inc.
 *
 * This program is free software; you can redistribute  it and/or modify it
 * under  the terms of  the GNU General  Public License as published by the
 * Free Software Foundation;  either version 2 of the  License, or (at your
 * option) any later version.
 */
#define DEBUG 1
#define pr_fmt(fmt) "[%s,%d]: " fmt "\n", __func__, __LINE__
#include <linux/delay.h>
#include <linux/err.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/mm.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_irq.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/spi/spi.h>
#include <linux/pm_runtime.h>
#include <linux/gpio.h>
#include <linux/of_gpio.h>

#define dbg_print(fmt, arg...) do { pr_info(fmt, ##arg); } while(0)

/* eSPI Controller registers */
#define SPI_SPMODE     0x00    /* SPI mode register */
#define SPI_SPIE       0x04    /* SPI event register */
#define SPI_SPIM       0x08    /* SPI mask register */
#define SPI_SPCOM      0x0c    /* SPI command register */
#define SPI_SPITD      0x10    /* SPI transmitter register*/
#define SPI_SPIRD      0x14    /* SPI receiver access register*/
#define SPI_SPMODE0    0x20    /* SPI cs0 mode register */

#define SPI_SPMODEx(x) (SPI_SPMODE0 + (x) * 4)

/* eSPI Controller mode register definitions */
#define SPMODE_ENABLE        BIT(31)
#define SPMODE_LOOP          BIT(30)

/* eSPI Controller CS mode register definitions */
#define CSMODE_CI_INACTIVEHIGH  BIT(31)
#define CSMODE_CP_BEGIN_EDGECLK BIT(30)
#define CSMODE_REV              BIT(29)
#define CSMODE_DIV16            BIT(28)
#define CSMODE_PM(x)            ((x) << 24)
#define CSMODE_POL_1            BIT(20)
#define CSMODE_LEN(x)           ((x) << 16)
#define CSMODE_BEF(x)           ((x) << 12)
#define CSMODE_AFT(x)           ((x) << 8)
#define CSMODE_CG(x)            ((x) << 3)

/* Default mode/csmode for eSPI controller */
#define SPMODE_INIT_VAL (SPMODE_ENABLE)
#define CSMODE_INIT_VAL (CSMODE_POL_1 | CSMODE_BEF(3) \
        | CSMODE_AFT(3) | CSMODE_CG(5))

/* SPIE register values */
#define SPIE_RXCNT(reg) ((reg >> 24) & 0x3F)
#define SPIE_DON        BIT(14)    /* Frame(xfer) done  */
#define SPIE_DNR        BIT(13)    /* Data not ready, slave only */
#define SPIE_OV         BIT(12)    /* Slave/Master overrun */
#define SPIE_UN         BIT(11)    /* Slave unerrun */
#define SPIE_MME        BIT(10)    /* Multiple master error */
#define SPIE_RNE        BIT(9)     /* Receiver not empty */
#define SPIE_TNF        BIT(8)     /* Transmitter not full */

/* SPIM register values */
#define SPIM_DON        BIT(14)    /* Frame(xfer) done  */
#define SPIM_DNR        BIT(13)    /* Data not ready, slave only */
#define SPIM_OV         BIT(12)    /* Slave/Master overrun */
#define SPIM_UN         BIT(11)    /* Slave unerrun */
#define SPIM_MME        BIT(10)    /* Multiple master error */
#define SPIM_RNE        BIT(9)     /* Receiver not empty */
#define SPIM_TNF        BIT(8)     /* Transmitter not full */

/* SPCOM register values */
#define SPCOM_CS(x)         ((x) << 30)
#define SPCOM_DO            BIT(28) /* Dual output */
#define SPCOM_TO            BIT(27) /* TX only */
#define SPCOM_RXSKIP(x)     ((x) << 16)
#define SPCOM_TRANLEN(x)    ((x) << 0)

#define SPCOM_TRANLEN_MAX   0x10000    /* Max transaction length */

#define AUTOSUSPEND_TIMEOUT 2000

struct szhz_spi {
    struct device *dev;
    void __iomem *reg_base;

    struct list_head *m_transfers;
    struct spi_transfer *tx_t;
    unsigned int tx_pos;
    bool tx_done;
    struct spi_transfer *rx_t;
    unsigned int rx_pos;
    unsigned int xfer_count;
    unsigned int xfer_len; /* frmae_len */
    bool rx_done;

    bool swab;
    unsigned int rxskip;

    spinlock_t lock;

    u32 spibrg;             /* SPIBRG input clock */

    struct completion done;
};

struct szhz_spi_cs {
    u32 hw_mode;
};

static inline u32 szhz_spi_read_reg(struct szhz_spi *spi, int offset)
{
    u32 val;

    val= ioread32(spi->reg_base + offset);
#if 0
    switch (offset) {
        case SPI_SPMODE    : dbg_print("SPI_SPMODE=0x%08x", val); break;
        case SPI_SPIE      : dbg_print("SPI_SPIE=0x%08x", val); break;
        case SPI_SPIM      : dbg_print("SPI_SPIM=0x%08x", val); break;
        case SPI_SPCOM     : dbg_print("SPI_SPCOM=0x%08x", val); break;
        case SPI_SPITD     : dbg_print("SPI_SPITD=0x%08x", val); break;
        case SPI_SPIRD     : dbg_print("SPI_SPIRD=0x%08x", val); break;
        case SPI_SPMODEx(0): dbg_print("SPI_SPMODE0=0x%08x", val); break;
        case SPI_SPMODEx(1): dbg_print("SPI_SPMODE1=0x%08x", val); break;
        case SPI_SPMODEx(2): dbg_print("SPI_SPMODE2=0x%08x", val); break;
        case SPI_SPMODEx(3): dbg_print("SPI_SPMODE3=0x%08x", val); break;
    }
#endif
    return val;
}

static inline u16 szhz_spi_read_reg16(struct szhz_spi *spi, int offset)
{
    u16 val;
    val = ioread16(spi->reg_base + offset);
    dbg_print("offset=%d,val=0x%04x", offset, val);
    return val;
}

static inline u8 szhz_spi_read_reg8(struct szhz_spi *spi, int offset)
{
    u8 val;

    val = ioread8(spi->reg_base + offset);
    dbg_print("offset=%d,val=0x%02x", offset, val);
    return val;
}

static inline void szhz_spi_write_reg(struct szhz_spi *hzspi, int offset,
        u32 val)
{
#if 0
    switch (offset) {
        case SPI_SPMODE    : dbg_print("SPI_SPMODE=0x%08x", val); break;
        case SPI_SPIE      : dbg_print("SPI_SPIE=0x%08x", val); break;
        case SPI_SPIM      : dbg_print("SPI_SPIM=0x%08x", val); break;
        case SPI_SPCOM     : dbg_print("SPI_SPCOM=0x%08x", val); break;
        case SPI_SPITD     : dbg_print("SPI_SPITD=0x%08x", val); break;
        case SPI_SPIRD     : dbg_print("SPI_SPIRD=0x%08x", val); break;
        case SPI_SPMODEx(0): dbg_print("SPI_SPMODE0=0x%08x", val); break;
        case SPI_SPMODEx(1): dbg_print("SPI_SPMODE1=0x%08x", val); break;
        case SPI_SPMODEx(2): dbg_print("SPI_SPMODE2=0x%08x", val); break;
        case SPI_SPMODEx(3): dbg_print("SPI_SPMODE3=0x%08x", val); break;
    }
#endif
    iowrite32(val, hzspi->reg_base + offset);
}

static inline void szhz_spi_write_reg16(struct szhz_spi *hzspi, int offset,
        u16 val)
{
    dbg_print("offset=%d,val=0x%04x", offset, val);
    iowrite16(val, hzspi->reg_base + offset);
}

static inline void szhz_spi_write_reg8(struct szhz_spi *hzspi, int offset,
        u8 val)
{
    dbg_print("offset=%d,val=0x%02x", offset, val);
    iowrite8(val, hzspi->reg_base + offset);
}

static int szhz_spi_check_message(struct spi_message *m)
{
    struct szhz_spi *hzspi = spi_master_get_devdata(m->spi->master);
    struct spi_transfer *t, *first;

    if (m->frame_length > SPCOM_TRANLEN_MAX) {
        dev_err(hzspi->dev, "message too long, size is %u bytes\n",
                m->frame_length);
        return -EMSGSIZE;
    }

    first = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);

    list_for_each_entry(t, &m->transfers, transfer_list) {
        if (first->bits_per_word != t->bits_per_word ||
                first->speed_hz != t->speed_hz) {
            dev_err(hzspi->dev, "bits_per_word/speed_hz should be the same for all transfers\n");
            return -EINVAL;
        }
    }

    /* SPI supports MSB-first transfers for word size 8 / 16 only */
    if (!(m->spi->mode & SPI_LSB_FIRST) && first->bits_per_word != 8 &&
            first->bits_per_word != 16) {
        dev_err(hzspi->dev,
                "MSB-first transfer not supported for wordsize %u\n",
                first->bits_per_word);
        return -EINVAL;
    }

    return 0;
}

static unsigned int szhz_spi_check_rxskip_mode(struct spi_message *m)
{
    struct spi_transfer *t;
    unsigned int i = 0, rxskip = 0;

    /*
     * prerequisites for SPI rxskip mode:
     * - message has two transfers
     * - first transfer is a write and second is a read
     *
     * In addition the current low-level transfer mechanism requires
     * that the rxskip bytes fit into the TX FIFO. Else the transfer
     * would hang because after the first FSL_SPI_FIFO_SIZE bytes
     * the TX FIFO isn't re-filled.
     */
    list_for_each_entry(t, &m->transfers, transfer_list) {
        if (i == 0) {
            rxskip = t->len;
        } else if (i == 1) {
            if (t->tx_buf || !t->rx_buf)
                return 0;
        }
        i++;
    }
    return i == 2 ? rxskip : 0;
}

static inline void szhz_spi_fill_tansmitter(struct szhz_spi *hzspi, u32 events)
{
    u32 xfer_left;
    unsigned int tx_left;
    const void *tx_buf;
    u32 val = 0;
    u8 *buf;
    u32 mask;

    /* if events is zero transfer has not started and tx fifo is empty */
    xfer_left = hzspi->xfer_len - hzspi->xfer_count;
    if (0 == xfer_left) {
        return;
    }
    tx_left = hzspi->tx_t->len - hzspi->tx_pos;
    // dbg_print("tx_left=%d,tx_pos=%d,xfer_left=%d", tx_left, hzspi->tx_pos,xfer_left);
    tx_buf = hzspi->tx_t->tx_buf;
    if (tx_left >= 4) {
        buf = (u8 *)&val;
        memcpy(buf, tx_buf + hzspi->tx_pos, 4);
        hzspi->tx_pos += 4;
        // dbg_print("SPI_SPITD=0x%08x", val);
        szhz_spi_write_reg(hzspi, SPI_SPITD, val);
    } else if (tx_left > 0 && tx_left < 4) {
        buf = (u8 *)&val;
        memcpy(buf, tx_buf + hzspi->tx_pos, tx_left);
        hzspi->tx_pos += tx_left;
        // dbg_print("SPI_SPITD=0x%08x", val);
        szhz_spi_write_reg(hzspi, SPI_SPITD, val);
    } else /* if (xfer_left > 0) */ {
        // dbg_print("SPI_SPITD=0x%08x", 0);
        szhz_spi_write_reg(hzspi, SPI_SPITD, 0);
    } 
    hzspi->xfer_count += 4;
    if (hzspi->xfer_count > hzspi->xfer_len) {
        hzspi->xfer_count = hzspi->xfer_len;
    }
    if (hzspi->xfer_count == hzspi->xfer_len) {
        hzspi->tx_done = 1;
        mask = szhz_spi_read_reg(hzspi, SPI_SPIM);
        mask &= ~SPIM_TNF;
        szhz_spi_write_reg(hzspi, SPI_SPIM, mask);
    }
}

static inline void szhz_spi_cpfrom_receiver(struct szhz_spi *hzspi, u32 events)
{
    void *rx_buf;
    u32 mask;
    u32 val;
    u32 rxcnt;
    u32 rx_left;
    u32 idx;
    uint8_t *ptr;

    rx_buf = hzspi->rx_t->rx_buf;

    rxcnt = SPIE_RXCNT(events);
    if (rxcnt > 4) {
        for (idx = 0; idx < rxcnt; idx++) {
            *((uint8_t *)(rx_buf + hzspi->rx_pos + idx)) = 0x00;
        }
        hzspi->rx_pos = hzspi->rx_pos + rxcnt;
        pr_err("Receive data overflow! rxcnt=%u", rxcnt);
    }

    val = szhz_spi_read_reg(hzspi, SPI_SPIRD);

    ptr = (uint8_t *)&val;
    rx_left = min(4U, rxcnt);
    // dbg_print("SPI_SPIRD=0x%08x, rx_left=%u", val, rx_left);

    for (idx = 0; idx < rx_left; idx++) {
        *((uint8_t *)(rx_buf + hzspi->rx_pos)) = *(ptr + idx);
        hzspi->rx_pos++;
        if (hzspi->rx_pos == hzspi->rx_t->len) {
            mask = szhz_spi_read_reg(hzspi, SPI_SPIM);
            mask &= ~SPIM_RNE;
            szhz_spi_write_reg(hzspi, SPI_SPIM, mask);
            hzspi->rx_done = 1;
            return ;
        }
    }
}

static void szhz_spi_setup_transfer(struct spi_device *spi,
        struct spi_transfer *t)
{
    struct szhz_spi *hzspi = spi_master_get_devdata(spi->master);
    int bits_per_word = t ? t->bits_per_word : spi->bits_per_word;
    u32 pm, hz = t ? t->speed_hz : spi->max_speed_hz;
    struct szhz_spi_cs *cs = spi_get_ctldata(spi);
    u32 hw_mode_old = cs->hw_mode;

    /* mask out bits we are going to set */
    cs->hw_mode &= ~(CSMODE_LEN(0xF) | CSMODE_DIV16 | CSMODE_PM(0xF));

    cs->hw_mode |= CSMODE_LEN(bits_per_word - 1);

    pm = DIV_ROUND_UP(hzspi->spibrg, hz * 4) - 1;

    if (pm > 15) {
        cs->hw_mode |= CSMODE_DIV16;
        pm = DIV_ROUND_UP(hzspi->spibrg, hz * 16 * 4) - 1;
    }

    cs->hw_mode |= CSMODE_PM(pm);
    dbg_print("hw_mode=0x%08x", cs->hw_mode);

    /* don't write the mode register if the mode doesn't change */
    if (cs->hw_mode != hw_mode_old)
        szhz_spi_write_reg(hzspi, SPI_SPMODEx(spi->chip_select),
                cs->hw_mode);
}

static int szhz_spi_bufs(struct spi_device *spi, struct spi_transfer *t)
{
    struct szhz_spi *hzspi = spi_master_get_devdata(spi->master);
    unsigned int rx_len = t->len;
    u32 mask, spcom;
    int ret;

    reinit_completion(&hzspi->done);

    /* Set SPCOM[CS] and SPCOM[TRANLEN] field */
    spcom = SPCOM_CS(spi->chip_select);
    spcom |= SPCOM_TRANLEN(t->len - 1);

    /* configure RXSKIP mode */
    if (hzspi->rxskip) {
        spcom |= SPCOM_RXSKIP(hzspi->rxskip);
        rx_len = t->len - hzspi->rxskip;
    } else {
        hzspi->rx_done = true;
        spcom |= SPCOM_TO;
    }
    // dbg_print("rx_len=%d", rx_len);

    szhz_spi_write_reg(hzspi, SPI_SPCOM, spcom);

    /* enable interrupts */
    mask = SPIM_DON;
    if (hzspi->rxskip > 0) {
        mask |= SPIM_RNE;
    }
    szhz_spi_write_reg(hzspi, SPI_SPIM, mask);

    /* Prevent filling the fifo from getting interrupted */
    spin_lock_irq(&hzspi->lock);
    szhz_spi_fill_tansmitter(hzspi, 0);

    /* enable interrupts */
    if (t->len > 4) {
        mask |= SPIM_TNF;
    }
    szhz_spi_write_reg(hzspi, SPI_SPIM, mask);

    spin_unlock_irq(&hzspi->lock);

    /* Won't hang up forever, SPI bus sometimes got lost interrupts... */
    ret = wait_for_completion_timeout(&hzspi->done, 2 * HZ);
    if (ret == 0)
        dev_err(hzspi->dev, "Transfer timed out!\n");

    /* disable rx ints */
    szhz_spi_write_reg(hzspi, SPI_SPIM, 0);

    return ret == 0 ? -ETIMEDOUT : 0;
}

static int szhz_spi_trans(struct spi_message *m, struct spi_transfer *trans)
{
    struct szhz_spi *hzspi = spi_master_get_devdata(m->spi->master);
    struct spi_device *spi = m->spi;
    int ret;

    // dbg_print("Enter");
    /* In case of LSB-first and bits_per_word > 8 byte-swap all words */
    hzspi->swab = spi->mode & SPI_LSB_FIRST && trans->bits_per_word > 8;

    hzspi->m_transfers = &m->transfers;
    hzspi->tx_t = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);
    hzspi->tx_pos = 0;
    hzspi->tx_done = false;
    hzspi->rx_t = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);
    hzspi->rx_pos = 0;
    hzspi->rx_done = false;
    hzspi->xfer_count = 0;
    hzspi->xfer_len = trans->len;

    hzspi->rxskip = szhz_spi_check_rxskip_mode(m);
    if (trans->rx_nbits == SPI_NBITS_DUAL && !hzspi->rxskip) {
        dev_err(hzspi->dev, "Dual output mode requires RXSKIP mode!\n");
        return -EINVAL;
    }

    /* In RXSKIP mode skip first transfer for reads */
    if (hzspi->rxskip) {
        hzspi->rx_t = list_next_entry(hzspi->rx_t, transfer_list);
    }

    szhz_spi_setup_transfer(spi, trans);

    ret = szhz_spi_bufs(spi, trans);

    if (trans->delay_usecs)
        udelay(trans->delay_usecs);

    return ret;
}

static int szhz_spi_do_one_msg(struct spi_master *master,
        struct spi_message *m)
{
    unsigned int delay_usecs = 0, rx_nbits = 0;
    struct spi_transfer *t, trans = {};
    int ret;

    ret = szhz_spi_check_message(m);
    if (ret)
        goto out;

    list_for_each_entry(t, &m->transfers, transfer_list) {
        if (t->delay_usecs > delay_usecs)
            delay_usecs = t->delay_usecs;
        if (t->rx_nbits > rx_nbits)
            rx_nbits = t->rx_nbits;
    }

    t = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);

    trans.len = m->frame_length;
    trans.speed_hz = t->speed_hz;
    trans.bits_per_word = t->bits_per_word;
    trans.delay_usecs = delay_usecs;
    trans.rx_nbits = rx_nbits;

    dbg_print("len=%d,speed_hz=%d,bits_per_word=%d", trans.len, trans.speed_hz,trans.bits_per_word);
    if (trans.len)
        ret = szhz_spi_trans(m, &trans);

    m->actual_length = ret ? 0 : trans.len;
out:
    if (m->status == -EINPROGRESS)
        m->status = ret;

    spi_finalize_current_message(master);

    return 0;
}

static int szhz_spi_setup(struct spi_device *spi)
{
    struct szhz_spi *hzspi;
    u32 loop_mode;
    struct szhz_spi_cs *cs = spi_get_ctldata(spi);

    dbg_print("Enter");

    if (!cs) {
        cs = kzalloc(sizeof(*cs), GFP_KERNEL);
        if (!cs)
            return -ENOMEM;
        spi_set_ctldata(spi, cs);
    }

    hzspi = spi_master_get_devdata(spi->master);

    pm_runtime_get_sync(hzspi->dev);

    cs->hw_mode = szhz_spi_read_reg(hzspi, SPI_SPMODEx(spi->chip_select));
    dbg_print("hw_mode=0x%08x, chip_select=%d", cs->hw_mode, spi->chip_select);
    /* mask out bits we are going to set */
    cs->hw_mode &= ~(CSMODE_CP_BEGIN_EDGECLK | CSMODE_CI_INACTIVEHIGH
            | CSMODE_REV);

    if (spi->mode & SPI_CPHA)
        cs->hw_mode |= CSMODE_CP_BEGIN_EDGECLK;
    if (spi->mode & SPI_CPOL)
        cs->hw_mode |= CSMODE_CI_INACTIVEHIGH;
    if (!(spi->mode & SPI_LSB_FIRST))
        cs->hw_mode |= CSMODE_REV;

    /* Handle the loop mode */
    loop_mode = szhz_spi_read_reg(hzspi, SPI_SPMODE);
    loop_mode &= ~SPMODE_LOOP;
    if (spi->mode & SPI_LOOP)
        loop_mode |= SPMODE_LOOP;
    szhz_spi_write_reg(hzspi, SPI_SPMODE, loop_mode);

    szhz_spi_setup_transfer(spi, NULL);

    pm_runtime_mark_last_busy(hzspi->dev);
    pm_runtime_put_autosuspend(hzspi->dev);

    return 0;
}

static void szhz_spi_cleanup(struct spi_device *spi)
{
    struct szhz_spi_cs *cs = spi_get_ctldata(spi);

    kfree(cs);
    spi_set_ctldata(spi, NULL);
}

static irqreturn_t szhz_spi_irq(s32 irq, void *context_data)
{
    struct szhz_spi *hzspi = context_data;
    u32 events;
    u32 mask;

    spin_lock(&hzspi->lock);

    /* Get interrupt events(tx/rx) */
    events = szhz_spi_read_reg(hzspi, SPI_SPIE);
    mask   = szhz_spi_read_reg(hzspi, SPI_SPIM);
    if (events & SPIE_RNE) {
        szhz_spi_cpfrom_receiver(hzspi, events);
    }
    if (events & SPIE_TNF) {
        szhz_spi_fill_tansmitter(hzspi, events);
    }

    if (events & SPIE_DON) {
        complete(&hzspi->done);
    }

    /* Clear the events */
    szhz_spi_write_reg(hzspi, SPI_SPIE, events);

    spin_unlock(&hzspi->lock);

    // dbg_print("SPI_SPIE 0x%08x", events);

    return IRQ_HANDLED;
}

#ifdef CONFIG_PM
static int szhz_spi_runtime_suspend(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    struct szhz_spi *hzspi = spi_master_get_devdata(master);
    u32 regval;

    regval = szhz_spi_read_reg(hzspi, SPI_SPMODE);
    regval &= ~SPMODE_ENABLE;
    szhz_spi_write_reg(hzspi, SPI_SPMODE, regval);

    return 0;
}

static int szhz_spi_runtime_resume(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    struct szhz_spi *hzspi = spi_master_get_devdata(master);
    u32 regval;

    regval = szhz_spi_read_reg(hzspi, SPI_SPMODE);
    regval |= SPMODE_ENABLE;
    szhz_spi_write_reg(hzspi, SPI_SPMODE, regval);

    return 0;
}
#endif

static size_t szhz_spi_max_message_size(struct spi_device *spi)
{
    return SPCOM_TRANLEN_MAX;
}

static u32 get_sys_freq(struct device *dev)
{
    int ret;
    struct device_node *np = dev->of_node;
    unsigned int sys_freq;

    ret = of_property_read_u32(np, "clock-frequency", &sys_freq);
    if (ret) {
        return 100000000;
    }
    return sys_freq;
}

static void szhz_spi_init_regs(struct device *dev, bool initial)
{
    struct spi_master *master = dev_get_drvdata(dev);
    struct szhz_spi *hzspi = spi_master_get_devdata(master);
    struct device_node *nc;
    u32 csmode, cs, prop;
    int ret;

    /* SPI controller initializations */
    szhz_spi_write_reg(hzspi, SPI_SPMODE, 0);
    szhz_spi_write_reg(hzspi, SPI_SPIM, 0);
    szhz_spi_write_reg(hzspi, SPI_SPCOM, 0);
    szhz_spi_write_reg(hzspi, SPI_SPIE, 0xffffffff);

    /* Init eSPI CS mode register */
    for_each_available_child_of_node(master->dev.of_node, nc) {
        /* get chip select */
        ret = of_property_read_u32(nc, "reg", &cs);
        if (ret || cs >= master->num_chipselect)
            continue;

        csmode = CSMODE_INIT_VAL;

        /* check if CSBEF is set in device tree */
        ret = of_property_read_u32(nc, "szhz,csbef", &prop);
        dbg_print("szhz,csbef=%d", prop);
        if (!ret) {
            csmode &= ~(CSMODE_BEF(0xf));
            csmode |= CSMODE_BEF(prop);
        }

        /* check if CSAFT is set in device tree */
        ret = of_property_read_u32(nc, "szhz,csaft", &prop);
        dbg_print("szhz,csaft=%d", prop);
        if (!ret) {
            csmode &= ~(CSMODE_AFT(0xf));
            csmode |= CSMODE_AFT(prop);
        }

        szhz_spi_write_reg(hzspi, SPI_SPMODEx(cs), csmode);

        if (initial)
            dev_info(dev, "cs=%u, init_csmode=0x%x\n", cs, csmode);
    }

    /* Enable SPI interface */
    szhz_spi_write_reg(hzspi, SPI_SPMODE, SPMODE_INIT_VAL);
}

static int szhz_spi_probe(struct device *dev, struct resource *mem,
        unsigned int irq, unsigned int num_cs)
{
    struct spi_controller *master;
    struct szhz_spi *hzspi;
    int ret;
    unsigned long irqflags;

    dbg_print("Enter");

    master = spi_alloc_master(dev, sizeof(struct szhz_spi));
    if (!master)
        return -ENOMEM;

    dev_set_drvdata(dev, master);

    master->mode_bits = SPI_CPOL | SPI_CPHA | SPI_CS_HIGH |
        SPI_LSB_FIRST | SPI_LOOP;
    master->dev.of_node = dev->of_node;
    master->bits_per_word_mask = SPI_BPW_RANGE_MASK(4, 16);
    master->setup = szhz_spi_setup;
    master->cleanup = szhz_spi_cleanup;
    master->transfer_one_message = szhz_spi_do_one_msg;
    master->auto_runtime_pm = true;
    master->max_message_size = szhz_spi_max_message_size;
    master->num_chipselect = num_cs;

    hzspi = spi_master_get_devdata(master);
    spin_lock_init(&hzspi->lock);

    hzspi->dev = dev;
    hzspi->spibrg = get_sys_freq(dev);
    dbg_print("spibrg=%d", hzspi->spibrg);
    if (hzspi->spibrg == -1) {
        dev_err(dev, "Can't get sys frequency!\n");
        ret = -EINVAL;
        goto err_probe;
    }
    /* determined by clock divider fields DIV16/PM in register SPMODEx */
    master->min_speed_hz = DIV_ROUND_UP(hzspi->spibrg, 4 * 16 * 16);
    master->max_speed_hz = DIV_ROUND_UP(hzspi->spibrg, 4);

    init_completion(&hzspi->done);

    hzspi->reg_base = devm_ioremap_resource(dev, mem);
    dbg_print("reg_base=%p", hzspi->reg_base);
    if (IS_ERR(hzspi->reg_base)) {
        ret = PTR_ERR(hzspi->reg_base);
        dbg_print("reg_base error!");
        goto err_probe;
    }

    /* Register for SPI Interrupt */
    irqflags = IRQF_ONESHOT | IRQF_SHARED | IRQF_TRIGGER_RISING;
    ret = devm_request_irq(dev, irq, szhz_spi_irq, irqflags, "szhz_spi", hzspi);
    if (ret)
        goto err_probe;

    szhz_spi_init_regs(dev, true);

    pm_runtime_set_autosuspend_delay(dev, AUTOSUSPEND_TIMEOUT);
    pm_runtime_use_autosuspend(dev);
    pm_runtime_set_active(dev);
    pm_runtime_enable(dev);
    pm_runtime_get_sync(dev);

    ret = devm_spi_register_master(dev, master);
    if (ret < 0)
        goto err_pm;

    dev_info(dev, "at 0x%p (irq = %u)\n", hzspi->reg_base, irq);

    pm_runtime_mark_last_busy(dev);
    pm_runtime_put_autosuspend(dev);

    return 0;

err_pm:
    pm_runtime_put_noidle(dev);
    pm_runtime_disable(dev);
    pm_runtime_set_suspended(dev);
err_probe:
    spi_master_put(master);
    return ret;
}

static int of_szhz_spi_get_chipselects(struct device *dev)
{
    struct device_node *np = dev->of_node;
    u32 num_cs;
    int ret;

    ret = of_property_read_u32(np, "szhz,spi-num-chipselects", &num_cs);
    if (ret) {
        dev_err(dev, "No 'szhz,spi-num-chipselects' property\n");
        return 0;
    }

    return num_cs;
}

static int of_szhz_spi_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct device_node *np = pdev->dev.of_node;
    struct resource *res;
    unsigned int irq, num_cs;
    int ret = -1;

    dbg_print("Enter");
    if (of_property_read_bool(np, "mode")) {
        dev_err(dev, "mode property is not supported on SPI!\n");
        return -EINVAL;
    }

    num_cs = of_szhz_spi_get_chipselects(dev);
    dbg_print("num_cs=%d", num_cs);
    if (!num_cs)
        return -EINVAL;

    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    // ret = of_address_to_resource(np, 0, &mem);
    if (IS_ERR(res)) {
        dbg_print("res=%p", res);
        return ret;
    }

    ret = of_get_named_gpio(np, "irq-gpio", 0);
    dbg_print("irq-gpio=%d", ret);
    if (ret < 0) {
        return -EINVAL;
    }
    irq = gpio_to_irq(ret);
    dbg_print("irq=%d", irq);
    // irq = irq_of_parse_and_map(np, 0);
    if (!irq)
        return -EINVAL;

    return szhz_spi_probe(dev, res, irq, num_cs);
}

static int of_szhz_spi_remove(struct platform_device *dev)
{
    pm_runtime_disable(&dev->dev);

    return 0;
}

#ifdef CONFIG_PM_SLEEP
static int of_szhz_spi_suspend(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    int ret;

    ret = spi_master_suspend(master);
    if (ret) {
        dev_warn(dev, "cannot suspend master\n");
        return ret;
    }

    return pm_runtime_force_suspend(dev);
}

static int of_szhz_spi_resume(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    int ret;

    szhz_spi_init_regs(dev, false);

    ret = pm_runtime_force_resume(dev);
    if (ret < 0)
        return ret;

    return spi_master_resume(master);
}
#endif /* CONFIG_PM_SLEEP */

static const struct dev_pm_ops spi_pm = {
    SET_RUNTIME_PM_OPS(szhz_spi_runtime_suspend,
            szhz_spi_runtime_resume, NULL)
        SET_SYSTEM_SLEEP_PM_OPS(of_szhz_spi_suspend, of_szhz_spi_resume)
};

static const struct of_device_id of_szhz_spi_match[] = {
    { .compatible = "szhz,spi" },
    {}
};
MODULE_DEVICE_TABLE(of, of_szhz_spi_match);

static struct platform_driver szhz_spi_driver = {
    .driver = {
        .name = "szhz_spi",
        .of_match_table = of_szhz_spi_match,
        .pm = &spi_pm,
    },
    .probe        = of_szhz_spi_probe,
    .remove        = of_szhz_spi_remove,
};
module_platform_driver(szhz_spi_driver);

MODULE_AUTHOR("Luo Qiaofa");
MODULE_DESCRIPTION("Enhanced HuaZhen SPI Driver");
MODULE_LICENSE("GPL");
