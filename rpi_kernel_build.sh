#!/bin/bash                                                                                                                                                   [2/210]

OPT=$1
ARG2=$2
KERNEL=kernel_2712


function mod_install() {
    sudo make O=build -j6 modules_install
}
case $OPT in

b)
    echo "changed Local version ?"
    make O=build -j6 Image.gz modules dtbs
;;
menu)
    echo "make menuconfig"
    make O=build menuconfig
;;
def)
    KERNEL=kernel_2712
    make O=build bcm2712_defconfig
;;
mod_ins)
    mod_install
;;

mod_c)
    if [ -z "$ARG2" ]; then
        echo "enter second arg for the mod path"
        exit
    fi
    make O=build -j6 M=$ARG2
;;
mod_cp)
    if [ -z "$ARG2" ]; then
        echo "enter second arg for the mod to copy path"
        exit
    fi
   sudo cp  build/$ARG2/*.ko /lib/modules/`uname -r`/kernel/$ARG2
    sudo depmod -a
;;

copy)
    if [ -z "$ARG2" ]; then
        echo "enter second arg for the backup name"
        echo "copy stopped"
        exit
    fi
    mod_install
    sudo cp /boot/firmware/$KERNEL.img /boot/firmware/$KERNEL-backup-$ARG2.img
    sudo cp build/arch/arm64/boot/Image.gz /boot/firmware/$KERNEL.img
    sudo cp build/arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
    sudo cp build/arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
    sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/
;;

*)

echo "wrong arg"
echo "b    -> build"
echo "menu -> menuconfig"
echo "def  -> defconfig rpi5"
echo "mod_ins -> modules_install"
echo "copy -> copy files to boot"
echo "mod_c-> build custom module"
echo "mod_cp-> copy custom module"

exit
;;
esac

