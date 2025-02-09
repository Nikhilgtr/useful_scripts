#!/bin/bash

# Open first tab and run OpenOCD
gnome-terminal --tab -- bash -c "
echo 'Starting OpenOCD...';
cd openocd;
./src/openocd -f tcl/interface/ftdi/ft232h-rpi4.cfg -f tcl/target/bcm2711.cfg
exec bash"

sleep 4
# Open second tab and start GDB
gnome-terminal --tab -- bash -c "
echo 'Setting up GDB...';
gdb-multiarch linux/build/vmlinux -x gdb_setup.gdb
exec bash"

# Open third tab and start openocd telnet
gnome-terminal --tab -- bash -c "
echo 'Setting up openocd telnet...';
telnet 127.0.0.1 4444
exec bash"
