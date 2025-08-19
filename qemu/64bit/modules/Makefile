obj-m := bmp280-emul.o

KDIR := /home/nik/ws/buildroot/buildroot-2024.02.6/64_bit/build/linux-6.1.44/ # same kernel you boot in QEMU
PWD  := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

