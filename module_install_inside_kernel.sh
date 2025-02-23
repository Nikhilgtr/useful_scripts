#!/bin/bash

# Set your kernel source directory
KERNEL_SRC="$HOME/linux"  # Change this to your kernel source directory
DRIVER_NAME="my_driver"
DRIVER_PATH="drivers/misc/$DRIVER_NAME"

# Step 1: Check Kernel Source Directory
if [ ! -d "$KERNEL_SRC" ]; then
    echo "Kernel source not found at $KERNEL_SRC"
    exit 1
fi

# Step 2: Copy the Driver to Kernel Source
echo "Adding driver to the kernel..."
mkdir -p "$KERNEL_SRC/$DRIVER_PATH"
cp -r "$DRIVER_NAME"/* "$KERNEL_SRC/$DRIVER_PATH/"

# Step 3: Modify Kernel Makefile and Kconfig
echo "Updating kernel build system..."
echo "obj-\$(CONFIG_$DRIVER_NAME) += $DRIVER_NAME/" >> "$KERNEL_SRC/drivers/misc/Makefile"
echo "config $DRIVER_NAME" >> "$KERNEL_SRC/drivers/misc/Kconfig"
echo "    tristate \"$DRIVER_NAME support\"" >> "$KERNEL_SRC/drivers/misc/Kconfig"

# Step 4: Configure Kernel
cd "$KERNEL_SRC"
make menuconfig  # Or: make oldconfig (to keep old settings)

# Step 5: Build the Kernel
echo "Building kernel..."
make -j$(nproc)  # Adjust CPU cores for faster build

# Step 6: Install Modules
echo "Installing modules..."
sudo make modules_install

# Step 7: Install Kernel (Optional)
echo "Installing new kernel..."
sudo make install

# Step 8: Update GRUB and Reboot (Optional)
echo "Updating GRUB..."
sudo update-grub
echo "Rebooting..."
sudo reboot
