#include <linux/module.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/reboot.h>

static int gpio_pin = 533; // Default GPIO pin, can be changed via module parameter
module_param(gpio_pin, int, 0444);
MODULE_PARM_DESC(gpio_pin, "GPIO pin number for the watchdog");

static irqreturn_t gpio_irq_handler(int irq, void *dev_id) {
    printk(KERN_INFO "GPIO interrupt triggered. Resetting system.\n");
    emergency_restart();
    return IRQ_HANDLED;
}

static int __init gpio_watchdog_init(void) {
    int irq, ret;

    // Request GPIO pin
    if (gpio_request(gpio_pin, "watchdog_gpio")) {
        printk(KERN_ERR "Failed to request GPIO pin %d\n", gpio_pin);
        return -1;
    }

    // Set GPIO pin as input
    gpio_direction_input(gpio_pin);

    // Get IRQ number for the GPIO pin
    irq = gpio_to_irq(gpio_pin);
    if (irq < 0) {
        printk(KERN_ERR "Failed to get IRQ for GPIO pin %d\n", gpio_pin);
        gpio_free(gpio_pin);
        return -1;
    }

    // Request IRQ handler
    ret = request_irq(irq, gpio_irq_handler, IRQF_TRIGGER_RISING, "watchdog_gpio", NULL);
    if (ret) {
        printk(KERN_ERR "Failed to request IRQ for GPIO pin %d\n", gpio_pin);
        gpio_free(gpio_pin);
        return -1;
    }

    printk(KERN_INFO "Nik: GPIO watchdog module loaded with GPIO pin %d.\n", gpio_pin);
    return 0;
}

static void __exit gpio_watchdog_exit(void) {
    free_irq(gpio_to_irq(gpio_pin), NULL);
    gpio_free(gpio_pin);
    printk(KERN_INFO "Nik GPIO watchdog module unloaded.\n");
}

module_init(gpio_watchdog_init);
module_exit(gpio_watchdog_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Nikhil Gautam");
MODULE_DESCRIPTION("GPIO Watchdog for Raspberry Pi");

