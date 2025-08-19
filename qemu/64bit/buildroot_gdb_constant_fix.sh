#!/bin/sh
# Usage: ./buildroot_gdb_constant_fix.sh output

KERNEL_DIR=$(ls -d $1/build/linux-*/ | head -n1)

echo "Fixing GDB Python constants in kernel source at $KERNEL_DIR"

# Re-generate constants with python3
#make -C "$KERNEL_DIR" scripts_gdb PYTHON=python3

# Clean up any lingering C-style suffixes (UL, ULL) just in case
sed -i -E 's/([0-9]+)U+L*/\1/g' "$KERNEL_DIR/scripts/gdb/linux/constants.py"

