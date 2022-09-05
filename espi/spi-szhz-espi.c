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
#define ESPI_SPMODE     0x00    /* eSPI mode register */
#define ESPI_SPIE       0x04    /* eSPI event register */
#define ESPI_SPIM       0x08    /* eSPI mask register */
#define ESPI_SPCOM      0x0c    /* eSPI command register */
#define ESPI_SPITF      0x10    /* eSPI transmit FIFO access register*/
#define ESPI_SPIRF      0x14    /* eSPI receive FIFO access register*/
#define ESPI_SPMODE0    0x20    /* eSPI cs0 mode register */

#define ESPI_SPMODEx(x) (ESPI_SPMODE0 + (x) * 4)

/* eSPI Controller mode register definitions */
#define SPMODE_ENABLE        BIT(31)
#define SPMODE_LOOP          BIT(30)
#define SPMODE_TXTHR(x)      ((x) << 8)
#define SPMODE_RXTHR(x)      ((x) << 0)

/* eSPI Controller CS mode register definitions */
#define CSMODE_CI_INACTIVEHIGH  BIT(31)
#define CSMODE_CP_BEGIN_EDGECLK BIT(30)
#define CSMODE_REV              BIT(29)
#define CSMODE_DIV16            BIT(28)
#define CSMODE_PM(x)            ((x) << 24)
#define CSMODE_3WIRE            BIT(23)
#define CSMODE_POL_1            BIT(20)
#define CSMODE_LEN(x)           ((x) << 16)
#define CSMODE_BEF(x)           ((x) << 12)
#define CSMODE_AFT(x)           ((x) << 8)
#define CSMODE_CG(x)            ((x) << 3)

#define HZ_ESPI_FIFO_SIZE      32
#define HZ_ESPI_RXTHR          15

/* Default mode/csmode for eSPI controller */
#define SPMODE_INIT_VAL (SPMODE_TXTHR(16) | SPMODE_RXTHR(15))
#define CSMODE_INIT_VAL (CSMODE_POL_1 | CSMODE_BEF(3) \
        | CSMODE_AFT(5) | CSMODE_CG(4))

/* SPIE register values */
#define SPIE_RXCNT(reg) ((reg >> 24) & 0x3F)
#define SPIE_TXCNT(reg) ((reg >> 16) & 0x3F)
#define SPIE_TXE        BIT(15)    /* TX FIFO empty */
#define SPIE_DON        BIT(14)    /* TX done */
#define SPIE_RXT        BIT(13)    /* RX FIFO threshold */
#define SPIE_RXF        BIT(12)    /* RX FIFO full */
#define SPIE_TXT        BIT(11)    /* TX FIFO threshold*/
#define SPIE_RNE        BIT(9)    /* RX FIFO not empty */
#define SPIE_TNF        BIT(8)    /* TX FIFO not full */

/* SPIM register values */
#define SPIM_TXE        BIT(15)    /* TX FIFO empty */
#define SPIM_DON        BIT(14)    /* TX done */
#define SPIM_RXT        BIT(13)    /* RX FIFO threshold */
#define SPIM_RXF        BIT(12)    /* RX FIFO full */
#define SPIM_TXT        BIT(11)    /* TX FIFO threshold*/
#define SPIM_RNE        BIT(9)    /* RX FIFO not empty */
#define SPIM_TNF        BIT(8)    /* TX FIFO not full */

/* SPCOM register values */
#define SPCOM_CS(x)         ((x) << 30)
#define SPCOM_DO            BIT(28) /* Dual output */
#define SPCOM_TO            BIT(27) /* TX only */
#define SPCOM_RXSKIP(x)     ((x) << 16)
#define SPCOM_TRANLEN(x)    ((x) << 0)

#define SPCOM_TRANLEN_MAX   0x10000    /* Max transaction length */

#define AUTOSUSPEND_TIMEOUT 2000

struct szhz_espi {
    struct device *dev;
    void __iomem *reg_base;

    struct list_head *m_transfers;
    struct spi_transfer *tx_t;
    unsigned int tx_pos;
    bool tx_done;
    struct spi_transfer *rx_t;
    unsigned int rx_pos;
    bool rx_done;

    bool swab;
    unsigned int rxskip;
    unsigned int xfer_len;
    unsigned int xfer_cnt;

    spinlock_t lock;

    u32 spibrg;             /* SPIBRG input clock */

    struct completion done;
};

struct szhz_espi_cs {
    u32 hw_mode;
};

static inline u32 szhz_espi_read_reg(struct szhz_espi *espi, int offset)
{
    u32 val;

    val= ioread32(espi->reg_base + offset);
#if 0
    switch (offset) {
        case ESPI_SPMODE    : dbg_print("ESPI_SPMODE=0x%08x", val); break;
        case ESPI_SPIE      : dbg_print("ESPI_SPIE=0x%08x", val); break;
        case ESPI_SPIM      : dbg_print("ESPI_SPIM=0x%08x", val); break;
        case ESPI_SPCOM     : dbg_print("ESPI_SPCOM=0x%08x", val); break;
        case ESPI_SPITF     : dbg_print("ESPI_SPITF=0x%08x", val); break;
        case ESPI_SPIRF     : dbg_print("ESPI_SPIRF=0x%08x", val); break;
        case ESPI_SPMODEx(0): dbg_print("ESPI_SPMODE0=0x%08x", val); break;
        case ESPI_SPMODEx(1): dbg_print("ESPI_SPMODE1=0x%08x", val); break;
        case ESPI_SPMODEx(2): dbg_print("ESPI_SPMODE2=0x%08x", val); break;
        case ESPI_SPMODEx(3): dbg_print("ESPI_SPMODE3=0x%08x", val); break;
    }
#endif
    return val;
}

static inline u16 szhz_espi_read_reg16(struct szhz_espi *espi, int offset)
{
    u16 val;
    val = ioread16(espi->reg_base + offset);
    // dbg_print("offset=%d,val=0x%04x", offset, val);
    return val;
}

static inline u8 szhz_espi_read_reg8(struct szhz_espi *espi, int offset)
{
    u8 val;

    val = ioread8(espi->reg_base + offset);
    // dbg_print("offset=%d,val=0x%02x", offset, val);
    return val;
}

static inline void szhz_espi_write_reg(struct szhz_espi *espi, int offset,
        u32 val)
{
#if 0
    switch (offset) {
        case ESPI_SPMODE    : dbg_print("ESPI_SPMODE=0x%08x", val); break;
        case ESPI_SPIE      : dbg_print("ESPI_SPIE=0x%08x", val); break;
        case ESPI_SPIM      : dbg_print("ESPI_SPIM=0x%08x", val); break;
        case ESPI_SPCOM     : dbg_print("ESPI_SPCOM=0x%08x", val); break;
        case ESPI_SPITF     : dbg_print("ESPI_SPITF=0x%08x", val); break;
        case ESPI_SPIRF     : dbg_print("ESPI_SPIRF=0x%08x", val); break;
        case ESPI_SPMODEx(0): dbg_print("ESPI_SPMODE0=0x%08x", val); break;
        case ESPI_SPMODEx(1): dbg_print("ESPI_SPMODE1=0x%08x", val); break;
        case ESPI_SPMODEx(2): dbg_print("ESPI_SPMODE2=0x%08x", val); break;
        case ESPI_SPMODEx(3): dbg_print("ESPI_SPMODE3=0x%08x", val); break;
    }
#endif
    iowrite32(val, espi->reg_base + offset);
}

static inline void szhz_espi_write_reg16(struct szhz_espi *espi, int offset,
        u16 val)
{
    // dbg_print("offset=%d,val=0x%04x", offset, val);
    iowrite16(val, espi->reg_base + offset);
}

static inline void szhz_espi_write_reg8(struct szhz_espi *espi, int offset,
        u8 val)
{
    // dbg_print("offset=%d,val=0x%02x", offset, val);
    iowrite8(val, espi->reg_base + offset);
}

static int szhz_espi_check_message(struct spi_message *m)
{
    struct szhz_espi *espi = spi_master_get_devdata(m->spi->master);
    struct spi_transfer *t, *first;

    if (m->frame_length > SPCOM_TRANLEN_MAX) {
        dev_err(espi->dev, "message too long, size is %u bytes\n",
                m->frame_length);
        return -EMSGSIZE;
    }

    first = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);

    list_for_each_entry(t, &m->transfers, transfer_list) {
        if (first->bits_per_word != t->bits_per_word ||
                first->speed_hz != t->speed_hz) {
            dev_err(espi->dev, "bits_per_word/speed_hz should be the same for all transfers\n");
            return -EINVAL;
        }
    }

    /* ESPI supports MSB-first transfers for word size 8 / 16 only */
    if (!(m->spi->mode & SPI_LSB_FIRST) && first->bits_per_word != 8 &&
            first->bits_per_word != 16) {
        dev_err(espi->dev,
                "MSB-first transfer not supported for wordsize %u\n",
                first->bits_per_word);
        return -EINVAL;
    }

    return 0;
}

static unsigned int szhz_espi_check_rxskip_mode(struct spi_message *m)
{
    struct spi_transfer *t;
    unsigned int rx_len = 0, i = 0;

    /*
     * prerequisites for ESPI rxskip mode:
     * - message has two transfers
     * - first transfer is a write and second is a read
     *
     * In addition the current low-level transfer mechanism requires
     * that the rxskip bytes fit into the TX FIFO. Else the transfer
     * would hang because after the first HZ_ESPI_FIFO_SIZE bytes
     * the TX FIFO isn't re-filled.
     */
    list_for_each_entry(t, &m->transfers, transfer_list) {
        if (NULL != t->rx_buf) {
            rx_len += t->len;
        }
        i++;
    }
    dbg_print("num spi_transfer=%u", i);
    return (m->frame_length - rx_len);
}

static void szhz_espi_fill_tx_fifo(struct szhz_espi *espi, u32 events)
{
    u32 val;
    u32 tx_fifo_avail;
    const void *tx_buf;
    unsigned int tx_left;
    unsigned int xfer_left;

    /* if events is zero transfer has not started and tx fifo is empty */
    tx_fifo_avail = events ? SPIE_TXCNT(events) :  HZ_ESPI_FIFO_SIZE;
    xfer_left = espi->xfer_len - espi->xfer_cnt;
    tx_left = espi->tx_t->len - espi->tx_pos;
    tx_buf = espi->tx_t->tx_buf;
    // while (tx_fifo_avail >= min(4U, tx_left) && xfer_left)
    while ((tx_fifo_avail >= 4) && (xfer_left > 0)) {
        val = 0;
        if (NULL != tx_buf) {
            if (tx_left >= 4) {
                memcpy((void *)&val, tx_buf + espi->tx_pos, 4);
                tx_left -= 4;
                espi->tx_pos += 4;
            } else if (tx_left > 0) {
                memcpy((void *)&val, tx_buf + espi->tx_pos, tx_left);
                espi->tx_pos += tx_left;
                tx_left = 0;
            } else {
                /* espi->xfer_cnt += 4; */
            }
        } else {
            /* tx_buf == NULL, rx_buf != NULL */
        }
        szhz_espi_write_reg(espi, ESPI_SPITF, val);

        tx_fifo_avail -= 4;
        if (xfer_left >= 4) {
            xfer_left -= 4;
        } else {
            xfer_left = 0;
        }
        espi->xfer_cnt += 4;
        if (0 == xfer_left) {
            espi->xfer_cnt = espi->xfer_len;
            espi->tx_done = true;
        }
    }
    // dbg_print("tx_left=%d,tx_buf=%p,tx_fifo_avail=%d", tx_left,tx_buf,tx_fifo_avail);
}

static void szhz_espi_read_rx_fifo(struct szhz_espi *espi, u32 events)
{
    u32 rx_fifo_avail = SPIE_RXCNT(events);
    unsigned int rx_left;
    void *rx_buf;
    uint32_t val32;

start:
    rx_buf = espi->rx_t->rx_buf;
    if (NULL == rx_buf) {
        espi->rx_done = true;
        return ;
    }
    rx_left = espi->rx_t->len - espi->rx_pos;
    // dbg_print("rx_left=%d,rx_pos=%d,rx_fifo_avail=%d", rx_left, espi->rx_pos,rx_fifo_avail);
    while (rx_fifo_avail >= min(4U, rx_left) && rx_left) {
        if (rx_fifo_avail >= 4) {
            if (rx_left >= 4) {
                val32 = szhz_espi_read_reg(espi, ESPI_SPIRF);
                if (espi->swab) {
                    val32 = swahb32(val32);
                }
                memcpy((rx_buf + espi->rx_pos), (void *)&val32, 4);
                espi->rx_pos += 4;
                rx_left -= 4;
                rx_fifo_avail -= 4;
            } else {
                val32 = szhz_espi_read_reg(espi, ESPI_SPIRF);
                memcpy(rx_buf + espi->rx_pos, (void *)&val32, rx_left);
                espi->rx_pos += rx_left;
                rx_fifo_avail -= rx_left;
                rx_left = 0;
            }
        } else {
            /* rx_fifo_avail >= rx_left && rx_left < 4 */
            val32 = szhz_espi_read_reg(espi, ESPI_SPIRF);
            memcpy(rx_buf + espi->rx_pos, (void *)&val32, rx_left);
            espi->rx_pos += rx_left;
            rx_fifo_avail -= rx_left;
            rx_left = 0;
        }
    }

    // dbg_print("rx_left=%d,rx_pos=%d,rx_fifo_avail=%d", rx_left, espi->rx_pos,rx_fifo_avail);
    if (!rx_left) {
        if (list_is_last(&espi->rx_t->transfer_list,
                    espi->m_transfers)) {
            espi->rx_done = true;
            return;
        }
        espi->rx_t = list_next_entry(espi->rx_t, transfer_list);
        espi->rx_pos = 0;
        /* continue with next transfer if rx fifo is not empty */
        if (rx_fifo_avail)
            goto start;
    }
}

static void szhz_espi_setup_transfer(struct spi_device *spi,
        struct spi_transfer *t)
{
    struct szhz_espi *espi = spi_master_get_devdata(spi->master);
    int bits_per_word = t ? t->bits_per_word : spi->bits_per_word;
    u32 pm, hz = t ? t->speed_hz : spi->max_speed_hz;
    struct szhz_espi_cs *cs = spi_get_ctldata(spi);
    u32 hw_mode_old = cs->hw_mode;

    /* mask out bits we are going to set */
    cs->hw_mode &= ~(CSMODE_LEN(0xF) | CSMODE_DIV16 | CSMODE_PM(0xF));

    cs->hw_mode |= CSMODE_LEN(bits_per_word - 1);

    pm = DIV_ROUND_UP(espi->spibrg, hz * 4) - 1;

    if (pm > 15) {
        cs->hw_mode |= CSMODE_DIV16;
        pm = DIV_ROUND_UP(espi->spibrg, hz * 16 * 4) - 1;
    }

    cs->hw_mode |= CSMODE_PM(pm);
    dbg_print("hw_mode=0x%08x", cs->hw_mode);

    /* don't write the mode register if the mode doesn't change */
    if (cs->hw_mode != hw_mode_old)
        szhz_espi_write_reg(espi, ESPI_SPMODEx(spi->chip_select),
                cs->hw_mode);
}

static int szhz_espi_bufs(struct spi_device *spi, struct spi_transfer *t)
{
    struct szhz_espi *espi = spi_master_get_devdata(spi->master);
    unsigned int rx_len = t->len;
    u32 mask, spcom;
    int ret;

    reinit_completion(&espi->done);

    /* Set SPCOM[CS] and SPCOM[TRANLEN] field */
    spcom = SPCOM_CS(spi->chip_select);
    spcom |= SPCOM_TRANLEN(t->len - 1);

    /* configure RXSKIP mode */
    if (espi->rxskip) {
        rx_len = t->len - espi->rxskip;
        if (0 == rx_len) {
            espi->rx_done = true;
            spcom |= SPCOM_TO;
        } else {
            spcom |= SPCOM_RXSKIP(espi->rxskip);
        }
    }

    szhz_espi_write_reg(espi, ESPI_SPCOM, spcom);

    /* enable interrupts */
    mask = SPIM_DON;
    if (rx_len > HZ_ESPI_FIFO_SIZE)
        mask |= SPIM_RXT;
    szhz_espi_write_reg(espi, ESPI_SPIM, mask);

    /* Prevent filling the fifo from getting interrupted */
    spin_lock_irq(&espi->lock);
    szhz_espi_fill_tx_fifo(espi, 0);
    spin_unlock_irq(&espi->lock);
    if (espi->xfer_len > HZ_ESPI_FIFO_SIZE) {
        mask |= SPIM_TXE;
        szhz_espi_write_reg(espi, ESPI_SPIM, mask);
    }

    /* Won't hang up forever, SPI bus sometimes got lost interrupts... */
    ret = wait_for_completion_timeout(&espi->done, 2 * HZ);
    if (ret == 0) {
        pr_err("tx_pos=%u,tx_done=%d, rx_pos=%u, rx_done=%d",
                espi->tx_pos, espi->tx_done, espi->rx_pos, espi->rx_done);
        dev_err(espi->dev, "Transfer timed out!\n");
    }

    /* disable rx ints */
    szhz_espi_write_reg(espi, ESPI_SPIM, 0);
    szhz_espi_write_reg(espi, ESPI_SPIE, 0xffffffff);

    return ret == 0 ? -ETIMEDOUT : 0;
}

static int szhz_espi_trans(struct spi_message *m, struct spi_transfer *trans)
{
    int ret;
    unsigned int rx_len;
    struct szhz_espi *espi = spi_master_get_devdata(m->spi->master);
    struct spi_device *spi = m->spi;

    /* In case of LSB-first and bits_per_word > 8 byte-swap all words */
    espi->swab = spi->mode & SPI_LSB_FIRST && trans->bits_per_word > 8;

    espi->m_transfers = &m->transfers;
    espi->tx_t = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);
    espi->tx_pos = 0;
    espi->tx_done = false;
    espi->rx_t = list_first_entry(&m->transfers, struct spi_transfer,
            transfer_list);
    espi->rx_pos = 0;
    espi->rx_done = false;
    espi->xfer_cnt = 0;
    espi->xfer_len = trans->len;

    espi->rxskip = szhz_espi_check_rxskip_mode(m);
    dbg_print("xfer_len=%u, rxskip=%u", espi->xfer_len, espi->rxskip);
    if (trans->rx_nbits == SPI_NBITS_DUAL && !espi->rxskip) {
        dev_err(espi->dev, "Dual output mode requires RXSKIP mode!\n");
        return -EINVAL;
    }

    dbg_print("tx_t=%p, tx_buf=%p", espi->tx_t, espi->tx_t->tx_buf);
    dbg_print("rx_t=%p, rx_buf=%p", espi->rx_t, espi->rx_t->rx_buf);
    /* In RXSKIP mode skip first transfer for reads */
    rx_len = m->frame_length - espi->rxskip;
    if ((rx_len > 0) && (NULL == espi->rx_t->rx_buf)) {
        espi->rx_t = list_next_entry(espi->rx_t, transfer_list);
        dbg_print("rx_t=%p, rx_buf=%p", espi->rx_t, espi->rx_t->rx_buf);
    }

    szhz_espi_setup_transfer(spi, trans);

    ret = szhz_espi_bufs(spi, trans);

    if (trans->delay_usecs)
        udelay(trans->delay_usecs);

    return ret;
}

static int szhz_espi_do_one_msg(struct spi_master *master,
        struct spi_message *m)
{
    unsigned int delay_usecs = 0, rx_nbits = 0;
    struct spi_transfer *t, trans = {};
    int ret;

    ret = szhz_espi_check_message(m);
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
        ret = szhz_espi_trans(m, &trans);

    m->actual_length = ret ? 0 : trans.len;
out:
    if (m->status == -EINPROGRESS)
        m->status = ret;

    spi_finalize_current_message(master);

    return 0;
}

static int szhz_espi_setup(struct spi_device *spi)
{
    struct szhz_espi *espi;
    u32 loop_mode;
    struct szhz_espi_cs *cs = spi_get_ctldata(spi);

    dbg_print("Enter");

    if (!cs) {
        cs = kzalloc(sizeof(*cs), GFP_KERNEL);
        if (!cs)
            return -ENOMEM;
        spi_set_ctldata(spi, cs);
    }

    espi = spi_master_get_devdata(spi->master);

    pm_runtime_get_sync(espi->dev);

    cs->hw_mode = szhz_espi_read_reg(espi, ESPI_SPMODEx(spi->chip_select));
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
    if (spi->mode & SPI_3WIRE) {
        cs->hw_mode |= CSMODE_3WIRE;
    }
    if (spi->mode & SPI_CS_HIGH) {
        cs->hw_mode &= ~CSMODE_POL_1;
    }

    /* Handle the loop mode */
    loop_mode = szhz_espi_read_reg(espi, ESPI_SPMODE);
    loop_mode &= ~SPMODE_LOOP;
    if (spi->mode & SPI_LOOP)
        loop_mode |= SPMODE_LOOP;
    szhz_espi_write_reg(espi, ESPI_SPMODE, loop_mode);

    szhz_espi_setup_transfer(spi, NULL);

    pm_runtime_mark_last_busy(espi->dev);
    pm_runtime_put_autosuspend(espi->dev);

    return 0;
}

static void szhz_espi_cleanup(struct spi_device *spi)
{
    struct szhz_espi_cs *cs = spi_get_ctldata(spi);

    kfree(cs);
    spi_set_ctldata(spi, NULL);
}

static void szhz_espi_cpu_irq(struct szhz_espi *espi, u32 events)
{
    if (!espi->rx_done)
        szhz_espi_read_rx_fifo(espi, events);

    if (!espi->tx_done) {
        // dbg_print("tx_done false");
        szhz_espi_fill_tx_fifo(espi, events);
    }

    // dbg_print("tx_done=%d,rx_done=%d", espi->tx_done, espi->rx_done);
    if (!espi->tx_done || !espi->rx_done)
        return;

    /* we're done, but check for errors before returning */
    events = szhz_espi_read_reg(espi, ESPI_SPIE);
    // dbg_print("events=0x%08x", events);

    if (SPIE_RXCNT(events) || SPIE_TXCNT(events) != HZ_ESPI_FIFO_SIZE)
        dev_err(espi->dev, "Transfer done but rx/tx fifo's aren't empty!\n");

    complete(&espi->done);
}

static irqreturn_t szhz_espi_irq(s32 irq, void *context_data)
{
    struct szhz_espi *espi = context_data;
    u32 events;

    spin_lock(&espi->lock);

    /* Get interrupt events(tx/rx) */
    events = szhz_espi_read_reg(espi, ESPI_SPIE);
    // dbg_print("events 0x%08x", events);
    if (!events) {
        spin_unlock(&espi->lock);
        return IRQ_NONE;
    }

    szhz_espi_cpu_irq(espi, events);

    /* Clear the events */
    szhz_espi_write_reg(espi, ESPI_SPIE, events);

    spin_unlock(&espi->lock);

    return IRQ_HANDLED;
}

#ifdef CONFIG_PM
static int szhz_espi_runtime_suspend(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    struct szhz_espi *espi = spi_master_get_devdata(master);
    u32 regval;

    regval = szhz_espi_read_reg(espi, ESPI_SPMODE);
    regval &= ~SPMODE_ENABLE;
    szhz_espi_write_reg(espi, ESPI_SPMODE, regval);

    return 0;
}

static int szhz_espi_runtime_resume(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    struct szhz_espi *espi = spi_master_get_devdata(master);
    u32 regval;

    regval = szhz_espi_read_reg(espi, ESPI_SPMODE);
    regval |= SPMODE_ENABLE;
    szhz_espi_write_reg(espi, ESPI_SPMODE, regval);

    return 0;
}
#endif

static size_t szhz_espi_max_message_size(struct spi_device *spi)
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

static void szhz_espi_init_regs(struct device *dev, bool initial)
{
    struct spi_master *master = dev_get_drvdata(dev);
    struct szhz_espi *espi = spi_master_get_devdata(master);
    struct device_node *nc;
    u32 csmode, cs, prop;
    int ret;

    /* SPI controller initializations */
    szhz_espi_write_reg(espi, ESPI_SPMODE, 0);
    szhz_espi_write_reg(espi, ESPI_SPIM, 0);
    szhz_espi_write_reg(espi, ESPI_SPCOM, 0);
    szhz_espi_write_reg(espi, ESPI_SPIE, 0xffffffff);

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

        szhz_espi_write_reg(espi, ESPI_SPMODEx(cs), csmode);

        if (initial)
            dev_info(dev, "cs=%u, init_csmode=0x%x\n", cs, csmode);
    }

    /* Enable SPI interface */
    szhz_espi_write_reg(espi, ESPI_SPMODE, SPMODE_INIT_VAL | SPMODE_ENABLE);
}

static int szhz_espi_probe(struct device *dev, struct resource *mem,
        unsigned int irq, unsigned int num_cs)
{
    struct spi_controller *master;
    struct szhz_espi *espi;
    int ret;
    unsigned long irqflags;

    dbg_print("Enter");

    master = spi_alloc_master(dev, sizeof(struct szhz_espi));
    if (!master)
        return -ENOMEM;

    dev_set_drvdata(dev, master);

    master->mode_bits = SPI_CPOL | SPI_CPHA | SPI_CS_HIGH |
        SPI_LSB_FIRST | SPI_LOOP | SPI_3WIRE;
    master->dev.of_node = dev->of_node;
    master->bits_per_word_mask = SPI_BPW_RANGE_MASK(4, 16);
    master->setup = szhz_espi_setup;
    master->cleanup = szhz_espi_cleanup;
    master->transfer_one_message = szhz_espi_do_one_msg;
    master->auto_runtime_pm = true;
    master->max_message_size = szhz_espi_max_message_size;
    master->num_chipselect = num_cs;

    espi = spi_master_get_devdata(master);
    spin_lock_init(&espi->lock);

    espi->dev = dev;
    espi->spibrg = get_sys_freq(dev);
    dbg_print("spibrg=%d", espi->spibrg);
    if (espi->spibrg == -1) {
        dev_err(dev, "Can't get sys frequency!\n");
        ret = -EINVAL;
        goto err_probe;
    }
    /* determined by clock divider fields DIV16/PM in register SPMODEx */
    master->min_speed_hz = DIV_ROUND_UP(espi->spibrg, 4 * 16 * 16);
    master->max_speed_hz = DIV_ROUND_UP(espi->spibrg, 4);

    init_completion(&espi->done);

    espi->reg_base = devm_ioremap_resource(dev, mem);
    dbg_print("reg_base=%p", espi->reg_base);
    if (IS_ERR(espi->reg_base)) {
        ret = PTR_ERR(espi->reg_base);
        dbg_print("reg_base error!");
        goto err_probe;
    }

    /* Register for SPI Interrupt */
    irqflags = IRQF_ONESHOT | IRQF_SHARED | IRQF_TRIGGER_RISING;
    ret = devm_request_irq(dev, irq, szhz_espi_irq, irqflags, "szhz_espi", espi);
    if (ret)
        goto err_probe;

    szhz_espi_init_regs(dev, true);

    pm_runtime_set_autosuspend_delay(dev, AUTOSUSPEND_TIMEOUT);
    pm_runtime_use_autosuspend(dev);
    pm_runtime_set_active(dev);
    pm_runtime_enable(dev);
    pm_runtime_get_sync(dev);

    ret = devm_spi_register_master(dev, master);
    if (ret < 0)
        goto err_pm;

    dev_info(dev, "at 0x%p (irq = %u)\n", espi->reg_base, irq);

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

static int of_szhz_espi_get_chipselects(struct device *dev)
{
    struct device_node *np = dev->of_node;
    u32 num_cs;
    int ret;

    ret = of_property_read_u32(np, "szhz,espi-num-chipselects", &num_cs);
    if (ret) {
        dev_err(dev, "No 'szhz,espi-num-chipselects' property\n");
        return 0;
    }

    return num_cs;
}

static int of_szhz_espi_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct device_node *np = pdev->dev.of_node;
    struct resource *res;
    unsigned int irq, num_cs;
    int ret = -1;

    dbg_print("Enter");
    if (of_property_read_bool(np, "mode")) {
        dev_err(dev, "mode property is not supported on ESPI!\n");
        return -EINVAL;
    }

    num_cs = of_szhz_espi_get_chipselects(dev);
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

    return szhz_espi_probe(dev, res, irq, num_cs);
}

static int of_szhz_espi_remove(struct platform_device *dev)
{
    pm_runtime_disable(&dev->dev);

    return 0;
}

#ifdef CONFIG_PM_SLEEP
static int of_szhz_espi_suspend(struct device *dev)
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

static int of_szhz_espi_resume(struct device *dev)
{
    struct spi_master *master = dev_get_drvdata(dev);
    int ret;

    szhz_espi_init_regs(dev, false);

    ret = pm_runtime_force_resume(dev);
    if (ret < 0)
        return ret;

    return spi_master_resume(master);
}
#endif /* CONFIG_PM_SLEEP */

static const struct dev_pm_ops espi_pm = {
    SET_RUNTIME_PM_OPS(szhz_espi_runtime_suspend,
            szhz_espi_runtime_resume, NULL)
        SET_SYSTEM_SLEEP_PM_OPS(of_szhz_espi_suspend, of_szhz_espi_resume)
};

static const struct of_device_id of_szhz_espi_match[] = {
    { .compatible = "szhz,espi" },
    {}
};
MODULE_DEVICE_TABLE(of, of_szhz_espi_match);

static struct platform_driver szhz_espi_driver = {
    .driver = {
        .name = "szhz_espi",
        .of_match_table = of_szhz_espi_match,
        .pm = &espi_pm,
    },
    .probe        = of_szhz_espi_probe,
    .remove        = of_szhz_espi_remove,
};
module_platform_driver(szhz_espi_driver);

MODULE_AUTHOR("Luo Qiaofa");
MODULE_DESCRIPTION("Enhanced HuaZhen SPI Driver");
MODULE_LICENSE("GPL");
