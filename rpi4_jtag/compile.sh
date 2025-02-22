#!/bin/bash

OPT=$1
ARG2=$2
KERNEL="kernel8"
BUILD_DIR="build"    
IP="192.168.1.28"    
USER="nik"    

function mod_install() {
    local MODULES_TAR="modules.tar.gz"
    local COMPILED_MODULES_DIR="$BUILD_DIR/mod_ins"
    
    rm -rf $COMPILED_MODULES_DIR
    mkdir $COMPILED_MODULES_DIR
        
    make O=$BUILD_DIR -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=`pwd`/$COMPILED_MODULES_DIR modules_install 
    tar -cvzf "$MODULES_TAR" -C "$COMPILED_MODULES_DIR" "."
    echo "Transferring files to the target..."
    scp "$MODULES_TAR" "$USER@$IP:/tmp/"

    echo "Installing modules on the target..."
    ssh "$USER@$IP" <<EOF
    set -e
    echo "Extracting modules..."
    mkdir /tmp/mod
    tar -xzf /tmp/$MODULES_TAR -C /tmp/mod/
    
    sudo mv /tmp/mod/lib/modules/* /lib/modules

    echo "Updating modules..."
    sudo depmod -a

    echo "Cleaning up..."
    rm /tmp/$MODULES_TAR
    rm -rf /tmp/mod/

    echo "Modules installed successfully."
EOF
}

case $OPT in 

b)
    echo "changed Local version ?"
    make O=$BUILD_DIR -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz modules dtbs
;;
menu)
    make -j4 O=$BUILD_DIR ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
;;
def)
    make O=$BUILD_DIR ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
;;
mod_ins)
    mod_install
;;

mod_c)
    if [ -z "$ARG2" ]; then
        echo "enter second arg for the mod path"
        exit
    fi
    make O=$BUILD_DIR -j6 M=$ARG2
;;
copy)
    mod_install
    ssh $USER@$IP "sudo cp /boot/firmware/$KERNEL.img /boot/firmware/$KERNEL-backup.img"
    scp $BUILD_DIR/arch/arm64/boot/Image $USER@$IP:/tmp/$KERNEL.img
    ssh $USER@$IP "sudo cp /tmp/$KERNEL.img /boot/firmware/$KERNEL.img"
    
    #Reboot the target
    echo "Rebooting the target to apply changes..."
    ssh "$USER@$IP" "sudo reboot"
    
    exit
    ssh $USER@$IP "sudo mkdir /tmp/dtb"
    scp -r  $BUILD_DIR/arch/arm64/boot/dts/broadcom/*.dtb $USER@$IP:/tmp/dtb
    ssh $USER@$IP "sudo mv /tmp/dtb/* /boot/firmware && rm -rf /tmp/dtb"
    
    ssh $USER@$IP "sudo mkdir /tmp/overlay"
    scp -r  $BUILD_DIR/arch/arm64/boot/dts/overlays/*.dtb* $USER@$IP:/tmp/overlay
    ssh $USER@$IP "sudo mv /tmp/overlay/* /boot/firmware/overlays && rm -rf /tmp/overlays"

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


