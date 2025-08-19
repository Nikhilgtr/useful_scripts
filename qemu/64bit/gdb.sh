#!/bin/sh

# Adjust these if your paths change
KERNEL_DIR="/home/nik/ws/buildroot/buildroot-2024.02.6/64_bit/build/linux-6.1.44"
GDB="/home/nik/ws/buildroot/buildroot-2024.02.6/64_bit/host/bin/aarch64-buildroot-linux-gnu-gdb"
VMLINUX="${KERNEL_DIR}/vmlinux"
GDB_SCRIPT="${KERNEL_DIR}/vmlinux-gdb.py"

if [ ! -f "${VMLINUX}" ]; then
    echo "Error: vmlinux not found at ${VMLINUX}"
    exit 1
fi

if [ ! -f "${GDB_SCRIPT}" ]; then
    echo "Error: vmlinux-gdb.py not found at ${GDB_SCRIPT}"
    exit 1
fi

exec ${GDB} "${VMLINUX}" \
    -ex "source ${GDB_SCRIPT}" \
    -ex "target remote :1234"
