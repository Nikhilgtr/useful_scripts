#!/bin/sh

#
# use for loigging using ssh## $/. ssh -p 2222 root@localhost
#
BINARIES_DIR="${0%/*}/"
cd "${BINARIES_DIR}" || exit 1

mode_serial=false
mode_sys_qemu=false
while [ "$1" ]; do
    case "$1" in
    --serial-only|serial-only) mode_serial=true; shift;;
    --use-system-qemu) mode_sys_qemu=true; shift;;
    --) shift; break;;
    *) echo "unknown option: $1" >&2; exit 1;;
    esac
done

if ${mode_serial}; then
    EXTRA_ARGS='-nographic'
else
    EXTRA_ARGS='-serial stdio'
fi

if ! ${mode_sys_qemu}; then
    export PATH="/home/nik/ws/buildroot/buildroot-2025.02.3/out_arm/host/bin:${PATH}"
fi

# Network: forward host port 2222 to guest port 22 for SSH
NET_OPTS='-net nic,model=rtl8139 -net user,hostfwd=tcp::2222-:22'

exec qemu-system-arm \
    -M versatilepb \
    -kernel zImage \
    -dtb versatile-pb.dtb \
    -drive file=rootfs.ext2,if=scsi,format=raw \
    -append "rootwait root=/dev/sda console=ttyAMA0,115200" \
    ${NET_OPTS} \
    ${EXTRA_ARGS} \
    "$@"
