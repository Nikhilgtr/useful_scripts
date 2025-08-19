#include <linux/module.h>
#include <linux/i2c.h>

#define BMP280_I2C_ADDR 0x76
#define BMP280_CHIP_ID  0x58  /* real chip-id of BMP280 */

static int bmp280_emul_master_xfer(struct i2c_adapter *adap,
                                   struct i2c_msg *msgs, int num)
{
    int i;
    static u8 reg_addr;

    for (i = 0; i < num; i++) {
        struct i2c_msg *msg = &msgs[i];

        if (msg->addr != BMP280_I2C_ADDR)
            return -ENODEV;

        if (msg->flags & I2C_M_RD) {
            /* READ operation */
            if (reg_addr == 0xD0) {   /* Chip-ID register */
                msg->buf[0] = BMP280_CHIP_ID;
            } else {
                msg->buf[0] = 0x00;   /* return dummy for others */
            }
        } else {
            /* WRITE operation (set register address) */
            reg_addr = msg->buf[0];
        }
    }
    return num;
}

static u32 bmp280_emul_func(struct i2c_adapter *adap)
{
    return I2C_FUNC_I2C | I2C_FUNC_SMBUS_BYTE_DATA;
}

static const struct i2c_algorithm bmp280_emul_algo = {
    .master_xfer = bmp280_emul_master_xfer,
    .functionality = bmp280_emul_func,
};

static struct i2c_adapter bmp280_emul_adapter = {
    .owner = THIS_MODULE,
    .class = I2C_CLASS_HWMON,
    .algo = &bmp280_emul_algo,
    .name = "bmp280-emul-adapter",
};

static int __init bmp280_emul_init(void)
{
    int ret = i2c_add_adapter(&bmp280_emul_adapter);
    if (ret < 0)
        return ret;

    pr_info("bmp280-emul: registered fake BMP280 at 0x76\n");
    return 0;
}

static void __exit bmp280_emul_exit(void)
{
    i2c_del_adapter(&bmp280_emul_adapter);
    pr_info("bmp280-emul: removed\n");
}

module_init(bmp280_emul_init);
module_exit(bmp280_emul_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Fake BMP280 Emulator over I2C");

