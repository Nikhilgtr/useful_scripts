// drivers/i2c/busses/i2c-virt.c

#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/i2c.h>
#include <linux/io.h>
#include <linux/interrupt.h>

#define REG_CTRL     0x00
#define REG_ADDR     0x04
#define REG_DATA     0x08
#define REG_STATUS   0x0C
#define REG_IRQ_EN   0x10
#define REG_IRQ_STAT 0x14

#define STATUS_DONE (1<<0)
#define STATUS_ACK  (1<<1)
#define CTRL_START   (1 << 0)
#define CTRL_STOP    (1 << 1)
#define CTRL_READ    (1 << 2)
#define CTRL_WRITE   (1 << 3)

struct virt_i2c {
    void __iomem *base;
    int irq;
    struct i2c_adapter adap;
};

static int virt_i2c_xfer(struct i2c_adapter *adap,
                         struct i2c_msg msgs[], int num)
{
    struct virt_i2c *vi = i2c_get_adapdata(adap);
    int i, j;
    u32 status;

    for (i = 0; i < num; i++) {

        writel(msgs[i].addr, vi->base + REG_ADDR);

        /* START (no data yet) */
        writel(CTRL_START |
               ((msgs[i].flags & I2C_M_RD) ? CTRL_READ : 0),
               vi->base + REG_CTRL);

        while (!((status = readl(vi->base + REG_STATUS)) & STATUS_DONE))
            cpu_relax();

        if (!(status & STATUS_ACK))
            return -ENXIO;

        writel(1, vi->base + REG_IRQ_STAT);

        for (j = 0; j < msgs[i].len; j++) {

            if (msgs[i].flags & I2C_M_RD) {

                /* READ byte */
                writel(CTRL_READ, vi->base + REG_CTRL);

                while (!((status = readl(vi->base + REG_STATUS)) & STATUS_DONE))
                    cpu_relax();

                if (!(status & STATUS_ACK))
                    return -EIO;

                msgs[i].buf[j] = readl(vi->base + REG_DATA);

            } else {

                /* WRITE byte */
                writel(msgs[i].buf[j], vi->base + REG_DATA);
                writel(CTRL_WRITE, vi->base + REG_CTRL);

                while (!((status = readl(vi->base + REG_STATUS)) & STATUS_DONE))
                    cpu_relax();

                if (!(status & STATUS_ACK))
                    return -EIO;
            }

            writel(1, vi->base + REG_IRQ_STAT);
        }
    }

    /* STOP once at end */
    writel(CTRL_STOP, vi->base + REG_CTRL);

    return num;
}

static u32 virt_i2c_func(struct i2c_adapter *adap)
{
    return I2C_FUNC_I2C |
           I2C_FUNC_SMBUS_BYTE |
           I2C_FUNC_SMBUS_BYTE_DATA |
           I2C_FUNC_SMBUS_READ_BYTE |
           I2C_FUNC_SMBUS_WRITE_BYTE |
           I2C_FUNC_SMBUS_WORD_DATA;
}

static const struct i2c_algorithm virt_i2c_algo = {
    .master_xfer = virt_i2c_xfer,
    .functionality = virt_i2c_func,
};

static int virt_i2c_probe(struct platform_device *pdev)
{
    struct virt_i2c *vi;
    struct resource *res;

    vi = devm_kzalloc(&pdev->dev, sizeof(*vi), GFP_KERNEL);
    if (!vi)
        return -ENOMEM;

    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    vi->base = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(vi->base))
        return PTR_ERR(vi->base);

    vi->adap.owner = THIS_MODULE;
    vi->adap.algo = &virt_i2c_algo;
    vi->adap.dev.parent = &pdev->dev;
    vi->adap.nr = -1;
    strscpy(vi->adap.name, "virt-i2c", sizeof(vi->adap.name));

    i2c_set_adapdata(&vi->adap, vi);

    return i2c_add_adapter(&vi->adap);
}

static const struct of_device_id virt_i2c_dt_ids[] = {
    { .compatible = "virt,i2c" },
    { }
};
MODULE_DEVICE_TABLE(of, virt_i2c_dt_ids);

static struct platform_driver virt_i2c_driver = {
    .probe = virt_i2c_probe,
    .driver = {
        .name = "virt-i2c",
        .of_match_table = virt_i2c_dt_ids,
    },
};

module_platform_driver(virt_i2c_driver);

MODULE_LICENSE("GPL");
