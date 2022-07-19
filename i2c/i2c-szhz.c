/*
 * (C) Copyright 2003-2004
 * Humboldt Solutions Ltd, adrian@humboldt.co.uk.

 * This is a combined i2c adapter and algorithm driver for the
 * MPC107/Tsi107 PowerPC northbridge and processors that include
 * the same I2C unit (8240, 8245, 85xx).
 *
 * Release 0.8
 *
 * This file is licensed under the terms of the GNU General Public
 * License version 2. This program is licensed "as is" without any
 * warranty of any kind, whether express or implied.
 */
#define DEBUG 1
#define pr_fmt(fmt) "[%s,%d]: " fmt "\n", __func__, __LINE__
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/sched/signal.h>
#include <linux/of_address.h>
#include <linux/of_irq.h>
#include <linux/of_platform.h>
#include <linux/slab.h>

#include <linux/clk.h>
#include <linux/io.h>
// #include <linux/szhz_devices.h>
#include <linux/i2c.h>
#include <linux/interrupt.h>
#include <linux/delay.h>
#include <linux/gpio.h>
#include <linux/of_gpio.h>

#define dbg_print(fmt, arg...) do { pr_notice(fmt, ##arg); } while(0)

// #include <sysdev/szhz_soc.h>

#define DRV_NAME "szhz-i2c"

#define SZHZ_I2C_CLOCK_LEGACY   0
#define SZHZ_I2C_CLOCK_PRESERVE (~0U)

#define SZHZ_I2C_FDR   0x04
#define SZHZ_I2C_CR    0x08
#define SZHZ_I2C_SR    0x0c
#define SZHZ_I2C_DR    0x10
#define SZHZ_I2C_DFSRR 0x14

#define CCR_MEN  0x80
#define CCR_MIEN 0x40
#define CCR_MSTA 0x20
#define CCR_MTX  0x10
#define CCR_TXAK 0x08
#define CCR_RSTA 0x04

#define CSR_MCF  0x80
#define CSR_MAAS 0x40
#define CSR_MBB  0x20
#define CSR_MAL  0x10
#define CSR_SRW  0x04
#define CSR_MIF  0x02
#define CSR_RXAK 0x01

struct szhz_i2c {
    struct device *dev;
    void __iomem *base;
    u32 interrupt;
    wait_queue_head_t queue;
    struct i2c_adapter adap;
    int irq;
    u32 real_clk;
#ifdef CONFIG_PM_SLEEP
    u8 fdr, dfsrr;
#endif
    struct clk *clk_per;
};

struct szhz_i2c_divider {
    u16 divider;
    u16 fdr;    /* including dfsrr */
};

struct szhz_i2c_data {
    void (*setup)(struct device_node *node, struct szhz_i2c *i2c,
            u32 clock, u32 prescaler);
    u32 prescaler;
};

static inline void writeccr(struct szhz_i2c *i2c, u32 x)
{
    dbg_print("CR=0x%02x", (u8)x);
    writeb(x, i2c->base + SZHZ_I2C_CR);
}

static irqreturn_t szhz_i2c_isr(int irq, void *dev_id)
{
    struct szhz_i2c *i2c = dev_id;
    u8 status;

    status = readb(i2c->base + SZHZ_I2C_SR);
    dbg_print("sr=0x%02x", status);
    if (status & CSR_MIF) {
        /* Read again to allow register to stabilise */
        i2c->interrupt = status;
        writeb(0, i2c->base + SZHZ_I2C_SR);
        wake_up(&i2c->queue);
        return IRQ_HANDLED;
    }
    return IRQ_NONE;
}

/* Sometimes 9th clock pulse isn't generated, and slave doesn't release
 * the bus, because it wants to send ACK.
 * Following sequence of enabling/disabling and sending start/stop generates
 * the 9 pulses, so it's all OK.
 */
static void szhz_i2c_fixup(struct szhz_i2c *i2c)
{
    int k;
    u32 delay_val = 1000000 / i2c->real_clk + 1;

    if (delay_val < 2)
        delay_val = 2;

    for (k = 9; k; k--) {
        writeccr(i2c, 0);
        writeccr(i2c, CCR_MSTA | CCR_MTX | CCR_MEN);
        readb(i2c->base + SZHZ_I2C_DR);
        writeccr(i2c, CCR_MEN);
        udelay(delay_val << 1);
    }
}

static int i2c_wait(struct szhz_i2c *i2c, unsigned timeout, int writing)
{
    unsigned long orig_jiffies = jiffies;
    u32 cmd_err;
    int result = 0;
    u8 status;

    if (!i2c->irq) {
        status = readb(i2c->base + SZHZ_I2C_SR);
        dbg_print("Read SR=0x%02x", status);
        while (!(status & CSR_MIF)) {
            schedule();
            if (time_after(jiffies, orig_jiffies + timeout)) {
                dev_dbg(i2c->dev, "timeout\n");
                writeccr(i2c, 0);
                result = -ETIMEDOUT;
                break;
            }
            status = readb(i2c->base + SZHZ_I2C_SR);
        }
        dbg_print("Read SR=0x%02x", status);
        cmd_err = readb(i2c->base + SZHZ_I2C_SR);
        writeb(0, i2c->base + SZHZ_I2C_SR);
        dbg_print("Write SR=0x%02x", 0);
    } else {
        /* Interrupt mode */
        result = wait_event_timeout(i2c->queue,
                (i2c->interrupt & CSR_MIF), timeout);

        if (unlikely(!(i2c->interrupt & CSR_MIF))) {
            dev_dbg(i2c->dev, "wait timeout\n");
            writeccr(i2c, 0);
            result = -ETIMEDOUT;
        }

        cmd_err = i2c->interrupt;
        i2c->interrupt = 0;
    }

    if (result < 0)
        return result;

    if (!(cmd_err & CSR_MCF)) {
        dev_dbg(i2c->dev, "unfinished\n");
        return -EIO;
    }

    if (cmd_err & CSR_MAL) {
        dev_dbg(i2c->dev, "MAL\n");
        return -EAGAIN;
    }

    if (writing && (cmd_err & CSR_RXAK)) {
        dev_dbg(i2c->dev, "No RXAK\n");
        /* generate stop */
        writeccr(i2c, CCR_MEN);
        return -ENXIO;
    }
    return 0;
}

static const struct szhz_i2c_divider szhz_i2c_dividers[] = {
    {256  , 0x1020}, {288  , 0x1021}, {320, 0x1022}  , {352  , 0x1023},
    {384  , 0x1000}, {384  , 0x1024}, {416, 0x1001}  , {448  , 0x1025},
    {480  , 0x1002}, {512  , 0x1026}, {576, 0x1003}  , {576  , 0x1027},
    {640  , 0x1004}, {640  , 0x1028}, {704, 0x1005}  , {768  , 0x1029},
    {832  , 0x1006}, {896  , 0x102A}, {1024, 0x1007} , {1024 , 0x102B},
    {1152 , 0x1008}, {1280 , 0x1009}, {1280, 0x102C} , {1536 , 0x100A},
    {1536 , 0x102D}, {1792 , 0x102E}, {1920, 0x100B} , {2048 , 0x102F},
    {2304 , 0x100C}, {2560 , 0x100D}, {2560, 0x1030} , {3072 , 0x100E},
    {3072 , 0x1031}, {3584 , 0x1032}, {3840, 0x100F} , {4096 , 0x1033},
    {4608 , 0x1010}, {5120 , 0x1011}, {5120, 0x1034} , {6144 , 0x1012},
    {6144 , 0x1035}, {7168 , 0x1036}, {7680, 0x1013} , {8192 , 0x1037},
    {9216 , 0x1014}, {10240, 0x1015}, {10240, 0x1038}, {12288, 0x1016},
    {12288, 0x1039}, {14336, 0x103A}, {15360, 0x1017}, {16384, 0x103B},
    {18432, 0x1018}, {20480, 0x1019}, {20480, 0x103C}, {24576, 0x101A},
    {24576, 0x103D}, {28672, 0x103E}, {30720, 0x101B}, {32768, 0x103F},
    {36864, 0x101C}, {40960, 0x101D}, {49152, 0x101E}, {61440, 0x101F}
};

static inline u32 szhz_i2c_get_prescaler(void)
{
    return 1;
}

static u32 szhz_get_sys_freq(struct device_node *np)
{
    int ret;
    unsigned int sys_freq = 0;

    ret = of_property_read_u32(np, "system-frequency", &sys_freq);
    dbg_print("sys_freq=%u", sys_freq);
    if (ret) {
        return 100000000;
    }
    return sys_freq;
}

static int szhz_i2c_get_fdr(struct device_node *node, u32 clock,
        u32 prescaler, u32 *real_clk)
{
    const struct szhz_i2c_divider *div = NULL;
    u32 divider;
    int i;

    if (clock == SZHZ_I2C_CLOCK_LEGACY) {
        /* see below - default fdr = 0x1031 -> div = 16 * 3072 */
        *real_clk = szhz_get_sys_freq(node) / prescaler / (16 * 3072);
        return -EINVAL;
    }

    /* Determine proper divider value */
    prescaler = szhz_i2c_get_prescaler();

    divider = szhz_get_sys_freq(node) / clock / prescaler;

    pr_debug("I2C: src_clock=%d clock=%d divider=%d\n",
            szhz_get_sys_freq(node), clock, divider);

    /*
     * We want to choose an FDR/DFSR that generates an I2C bus speed that
     * is equal to or lower than the requested speed.
     */
    for (i = 0; i < ARRAY_SIZE(szhz_i2c_dividers); i++) {
        div = &szhz_i2c_dividers[i];
        if (div->divider >= divider)
            break;
    }

    *real_clk = szhz_get_sys_freq(node) / prescaler / div->divider;
    return div ? (int)div->fdr : -EINVAL;
}

static void szhz_i2c_setup(struct device_node *node,
        struct szhz_i2c *i2c,
        u32 clock, u32 prescaler)
{
    int ret, fdr;

    if (clock == SZHZ_I2C_CLOCK_PRESERVE) {
        dev_dbg(i2c->dev, "using dfsrr %d, fdr %d\n",
                readb(i2c->base + SZHZ_I2C_DFSRR),
                readb(i2c->base + SZHZ_I2C_FDR));
        return;
    }

    ret = szhz_i2c_get_fdr(node, clock, prescaler, &i2c->real_clk);
    fdr = (ret >= 0) ? ret : 0x1031; /* backward compatibility */

    writeb(fdr & 0xff, i2c->base + SZHZ_I2C_FDR);
    dbg_print("FDR=0x%02x", fdr & 0xff);
    writeb((fdr >> 8) & 0xff, i2c->base + SZHZ_I2C_DFSRR);
    dbg_print("DFSRR=0x%02x", (fdr >> 8) & 0xff);

    if (ret >= 0)
        dev_info(i2c->dev, "clock %d Hz (dfsrr=%d fdr=%d)\n",
                i2c->real_clk, fdr >> 8, fdr & 0xff);
}

static void szhz_i2c_start(struct szhz_i2c *i2c)
{
    /* Clear arbitration */
    dbg_print("Write SR=0x%02x", 0);
    writeb(0, i2c->base + SZHZ_I2C_SR);
    /* Start with MEN */
    writeccr(i2c, CCR_MEN);
}

static void szhz_i2c_stop(struct szhz_i2c *i2c)
{
    writeccr(i2c, CCR_MEN);
}

static int szhz_write(struct szhz_i2c *i2c, int target,
        const u8 *data, int length, int restart)
{
    int i, result;
    unsigned timeout = i2c->adap.timeout;
    u32 flags = restart ? CCR_RSTA : 0;

    /* Start as master */
    writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA | CCR_MTX | flags);
    /* Write target byte */
    writeb((target << 1), i2c->base + SZHZ_I2C_DR);
    dbg_print("DR=0x%02x", (u8)(target << 1));

    result = i2c_wait(i2c, timeout, 1);
    if (result < 0)
        return result;

    for (i = 0; i < length; i++) {
        /* Write data byte */
        dbg_print("DR=0x%02x", data[i]);
        writeb(data[i], i2c->base + SZHZ_I2C_DR);

        result = i2c_wait(i2c, timeout, 1);
        if (result < 0)
            return result;
    }

    return 0;
}

static int szhz_read(struct szhz_i2c *i2c, int target,
        u8 *data, int length, int restart, bool recv_len)
{
    unsigned timeout = i2c->adap.timeout;
    int i, result;
    u32 flags = restart ? CCR_RSTA : 0;

    /* Switch to read - restart */
    writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA | CCR_MTX | flags);
    /* Write target address byte - this time with the read flag set */
    writeb((target << 1) | 1, i2c->base + SZHZ_I2C_DR);
    dbg_print("DR=0x%02x", (u8)((target << 1) | 1));

    result = i2c_wait(i2c, timeout, 1);
    if (result < 0)
        return result;

    if (length) {
        if (length == 1 && !recv_len)
            writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA | CCR_TXAK);
        else
            writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA);
        /* Dummy read */
        dbg_print("Dummy read DR");
        readb(i2c->base + SZHZ_I2C_DR);
    }

    for (i = 0; i < length; i++) {
        u8 byte;

        result = i2c_wait(i2c, timeout, 0);
        if (result < 0)
            return result;

        /*
         * For block reads, we have to know the total length (1st byte)
         * before we can determine if we are done.
         */
        if (i || !recv_len) {
            /* Generate txack on next to last byte */
            if (i == length - 2)
                writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA
                        | CCR_TXAK);
            /* Do not generate stop on last byte */
            if (i == length - 1)
                writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA
                        | CCR_MTX);
        }

        byte = readb(i2c->base + SZHZ_I2C_DR);
        dbg_print("read byte=0x%02x", byte);

        /*
         * Adjust length if first received byte is length.
         * The length is 1 length byte plus actually data length
         */
        if (i == 0 && recv_len) {
            if (byte == 0 || byte > I2C_SMBUS_BLOCK_MAX)
                return -EPROTO;
            length += byte;
            /*
             * For block reads, generate txack here if data length
             * is 1 byte (total length is 2 bytes).
             */
            if (length == 2)
                writeccr(i2c, CCR_MIEN | CCR_MEN | CCR_MSTA
                        | CCR_TXAK);
        }
        data[i] = byte;
    }

    return length;
}

static int szhz_xfer(struct i2c_adapter *adap, struct i2c_msg *msgs, int num)
{
    struct i2c_msg *pmsg;
    int i;
    int ret = 0;
    unsigned long orig_jiffies = jiffies;
    struct szhz_i2c *i2c = i2c_get_adapdata(adap);
    u8 status;

    szhz_i2c_start(i2c);

    /* Allow bus up to 1s to become not busy */
    status = readb(i2c->base + SZHZ_I2C_SR);
    dbg_print("Read SR=0x%02x", status);
    while (status & CSR_MBB) {
        if (signal_pending(current)) {
            dev_dbg(i2c->dev, "Interrupted\n");
            writeccr(i2c, 0);
            return -EINTR;
        }
        if (time_after(jiffies, orig_jiffies + HZ)) {
            status = readb(i2c->base + SZHZ_I2C_SR);
            dbg_print("Read SR=0x%02x", status);

            dev_dbg(i2c->dev, "timeout\n");
            if ((status & (CSR_MCF | CSR_MBB | CSR_RXAK)) != 0) {
                writeb(status & ~CSR_MAL,
                        i2c->base + SZHZ_I2C_SR);
                szhz_i2c_fixup(i2c);
            }
            return -EIO;
        }
        schedule();
        status = readb(i2c->base + SZHZ_I2C_SR);
    }
    dbg_print("Read SR=0x%02x", status);

    for (i = 0; ret >= 0 && i < num; i++) {
        pmsg = &msgs[i];
        dev_dbg(i2c->dev,
                "Doing %s %d bytes to 0x%02x - %d of %d messages\n",
                pmsg->flags & I2C_M_RD ? "read" : "write",
                pmsg->len, pmsg->addr, i + 1, num);
        if (pmsg->flags & I2C_M_RD) {
            bool recv_len = pmsg->flags & I2C_M_RECV_LEN;

            ret = szhz_read(i2c, pmsg->addr, pmsg->buf, pmsg->len, i, recv_len);
            if (recv_len && ret > 0)
                pmsg->len = ret;
        } else {
            ret = szhz_write(i2c, pmsg->addr, pmsg->buf, pmsg->len, i);
        }
    }
    szhz_i2c_stop(i2c); /* Initiate STOP */
    orig_jiffies = jiffies;
    /* Wait until STOP is seen, allow up to 1 s */
    status = readb(i2c->base + SZHZ_I2C_SR);
    dbg_print("Read SR=0x%02x", status);
    while (status & CSR_MBB) {
        if (time_after(jiffies, orig_jiffies + HZ)) {
            status = readb(i2c->base + SZHZ_I2C_SR);

            dev_dbg(i2c->dev, "timeout\n");
            if ((status & (CSR_MCF | CSR_MBB | CSR_RXAK)) != 0) {
                writeb(status & ~CSR_MAL,
                        i2c->base + SZHZ_I2C_SR);
                szhz_i2c_fixup(i2c);
            }
            return -EIO;
        }
        cond_resched();
        status = readb(i2c->base + SZHZ_I2C_SR);
    }
    dbg_print("Read SR=0x%02x", status);
    return (ret < 0) ? ret : num;
}

static u32 szhz_functionality(struct i2c_adapter *adap)
{
    return I2C_FUNC_I2C | I2C_FUNC_SMBUS_EMUL
        | I2C_FUNC_SMBUS_READ_BLOCK_DATA | I2C_FUNC_SMBUS_BLOCK_PROC_CALL;
}

static const struct i2c_algorithm szhz_algo = {
    .master_xfer = szhz_xfer,
    .functionality = szhz_functionality,
};

static struct i2c_adapter szhz_ops = {
    .owner = THIS_MODULE,
    .algo = &szhz_algo,
    .timeout = HZ,
};

static const struct of_device_id szhz_i2c_of_match[];
static int szhz_i2c_probe(struct platform_device *op)
{
    const struct of_device_id *match;
    struct szhz_i2c *i2c;
    u32 val32;
    u32 clock = SZHZ_I2C_CLOCK_LEGACY;
    int result = 0;
    struct resource res;
    unsigned long irqflags;
    int gpio;

    match = of_match_device(szhz_i2c_of_match, &op->dev);
    dbg_print("match=%p", match);
    if (!match)
        return -EINVAL;

    i2c = kzalloc(sizeof(*i2c), GFP_KERNEL);
    if (!i2c)
        return -ENOMEM;

    i2c->dev = &op->dev; /* for debug and error output */

    init_waitqueue_head(&i2c->queue);

    i2c->base = of_iomap(op->dev.of_node, 0);
    dbg_print("base=%p", i2c->base);
    if (!i2c->base) {
        dev_err(i2c->dev, "failed to map controller\n");
        result = -ENOMEM;
        goto fail_map;
    }
    i2c->base += 0x400;
    dbg_print("i2c base=%p", i2c->base);

    gpio = of_get_named_gpio(op->dev.of_node, "irq-gpio", 0);
    dbg_print("irq-gpio=%d", gpio);
    if (gpio > 0) { /* no i2c->irq implies polling */
        i2c->irq = gpio_to_irq(gpio);
        irqflags = IRQF_SHARED | IRQF_TRIGGER_RISING;
        result = request_irq(i2c->irq, szhz_i2c_isr,
                irqflags, "i2c-szhz", i2c);
        if (result < 0) {
            dev_err(i2c->dev, "failed to attach interrupt\n");
            goto fail_request;
        }
    }

    clock = 0;
    result = of_property_read_u32(op->dev.of_node, "clock-frequency", &clock);
    if (!result) {
        dbg_print("clock=%u", clock);
    }

    if (match->data) {
        const struct szhz_i2c_data *data = match->data;
        data->setup(op->dev.of_node, i2c, clock, data->prescaler);
    } else {
        szhz_i2c_setup(op->dev.of_node, i2c, clock, 1);
    }

    val32 = 0;
    result = of_property_read_u32(op->dev.of_node, "szhz,timeout", &val32);
    if (!result) {
        dbg_print("timeout=%u, HZ=%u", val32, HZ);
        szhz_ops.timeout = val32 * HZ / 1000000;
        if (szhz_ops.timeout < 5)
            szhz_ops.timeout = 5;
    }
    dev_info(i2c->dev, "timeout %u us\n", szhz_ops.timeout * 1000000 / HZ);

    platform_set_drvdata(op, i2c);

    i2c->adap = szhz_ops;
    of_address_to_resource(op->dev.of_node, 0, &res);
    scnprintf(i2c->adap.name, sizeof(i2c->adap.name),
            "Huazhen adapter at 0x%llx", (unsigned long long)res.start);
    i2c_set_adapdata(&i2c->adap, i2c);
    i2c->adap.dev.parent = &op->dev;
    i2c->adap.dev.of_node = of_node_get(op->dev.of_node);

    result = i2c_add_adapter(&i2c->adap);
    if (result < 0)
        goto fail_add;

    return result;

fail_add:
    if (i2c->clk_per)
        clk_disable_unprepare(i2c->clk_per);
    free_irq(i2c->irq, i2c);
fail_request:
    irq_dispose_mapping(i2c->irq);
    iounmap(i2c->base);
fail_map:
    kfree(i2c);
    return result;
};

static int szhz_i2c_remove(struct platform_device *op)
{
    struct szhz_i2c *i2c = platform_get_drvdata(op);

    i2c_del_adapter(&i2c->adap);

    if (i2c->clk_per)
        clk_disable_unprepare(i2c->clk_per);

    if (i2c->irq)
        free_irq(i2c->irq, i2c);

    irq_dispose_mapping(i2c->irq);
    iounmap(i2c->base);
    kfree(i2c);
    return 0;
};

#ifdef CONFIG_PM_SLEEP
static int szhz_i2c_suspend(struct device *dev)
{
    struct szhz_i2c *i2c = dev_get_drvdata(dev);

    i2c->fdr = readb(i2c->base + SZHZ_I2C_FDR);
    dbg_print("FDR=0x%02x", i2c->fdr);
    i2c->dfsrr = readb(i2c->base + SZHZ_I2C_DFSRR);
    dbg_print("DFSRR=0x%02x", i2c->dfsrr);

    return 0;
}

static int szhz_i2c_resume(struct device *dev)
{
    struct szhz_i2c *i2c = dev_get_drvdata(dev);

    writeb(i2c->fdr, i2c->base + SZHZ_I2C_FDR);
    dbg_print("FDR=0x%02x", i2c->fdr);
    writeb(i2c->dfsrr, i2c->base + SZHZ_I2C_DFSRR);
    dbg_print("DFSRR=0x%02x", i2c->dfsrr);

    return 0;
}

static SIMPLE_DEV_PM_OPS(szhz_i2c_pm_ops, szhz_i2c_suspend, szhz_i2c_resume);
#define SZHZ_I2C_PM_OPS  (&szhz_i2c_pm_ops)
#else
#define SZHZ_I2C_PM_OPS  NULL
#endif

static const struct szhz_i2c_data szhz_i2c_data = {
    .setup = szhz_i2c_setup,
    .prescaler = 1,
};

static const struct of_device_id szhz_i2c_of_match[] = {
    /* Backward compatibility */
    {.compatible = "szhz,szhz-i2c", },
    {},
};
MODULE_DEVICE_TABLE(of, szhz_i2c_of_match);

/* Structure for a device driver */
static struct platform_driver szhz_i2c_driver = {
    .probe  = szhz_i2c_probe,
    .remove = szhz_i2c_remove,
    .driver = {
        .name = DRV_NAME,
        .of_match_table = szhz_i2c_of_match,
        .pm = SZHZ_I2C_PM_OPS,
    },
};

module_platform_driver(szhz_i2c_driver);

MODULE_AUTHOR("luoqiaofa<luoqiaofa@163.com>");
MODULE_DESCRIPTION("I2C-Bus adapter for huazhen "
        "Compatible with Freescale MPC83xx processors");
MODULE_LICENSE("GPL");

