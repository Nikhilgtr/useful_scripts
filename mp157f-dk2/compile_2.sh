#!/bin/bash

# compile.sh - Compile and deploy kernel + modules to STM32MP157F-DK2

OPT=$1

#Add this in .ssh/config

#Host stm32mp1
#    HostName 192.168.7.1
#    User root
#    ControlMaster auto
#    ControlPath ~/.ssh/cm-%r@%h:%p
#    ControlPersist 10m

IP="stm32mp1"
KERNEL_DIR="linux-6.1.28"
ARCH="arm"
CROSS_COMPILE="arm-ostl-linux-gnueabi-"
CORE=$((2 * $(nproc)))

export OUTPUT_BUILD_DIR=$PWD/build
export IMAGE_KERNEL="uImage"
export STRIP="${CROSS_COMPILE}strip"

# Get kernel local version
CONFIG_LOCALVERSION=$(grep "^CONFIG_LOCALVERSION=" $OUTPUT_BUILD_DIR/.config 2>/dev/null | cut -d '"' -f2)
CONFIG_LOCALVERSION=${CONFIG_LOCALVERSION:-""}
KERNEL_VERSION="${KERNEL_DIR#linux-}${CONFIG_LOCALVERSION}"

ARTIFACT_DIR="${OUTPUT_BUILD_DIR}/install_artifact"
MODULES_DIR="${ARTIFACT_DIR}/lib/modules/${KERNEL_VERSION}"
BOOT_DIR="${ARTIFACT_DIR}/boot"

check_toolchain() {
    if ! command -v "${CROSS_COMPILE}gcc" &>/dev/null; then
        echo "Error: AArch64 toolchain (${CROSS_COMPILE}gcc) not found!"
        echo "Please run: source <SDK>/environment-setup-*"
        exit 1
    fi
}

defconfig() {
    rm -rf "${OUTPUT_BUILD_DIR}" "$KERNEL_DIR"
    mkdir -p "${OUTPUT_BUILD_DIR}"
    tar xf "${KERNEL_DIR}.tar.xz"
    cd "$KERNEL_DIR" || exit

    for patch in ../*.patch; do patch -p1 < "$patch"; done
    make O="${OUTPUT_BUILD_DIR}" multi_v7_defconfig

    for frag in ../fragment*.config; do
        scripts/kconfig/merge_config.sh -m -r -O "${OUTPUT_BUILD_DIR}" "${OUTPUT_BUILD_DIR}/.config" "$frag"
    done

    (yes '' || true) | make oldconfig O="${OUTPUT_BUILD_DIR}"
    cd - || exit
}

menuconfig() {
    cd "$KERNEL_DIR" || exit
    make -j"$CORE" O="${OUTPUT_BUILD_DIR}" menuconfig
    cd - || exit
}

build_kernel() {
    cd "$KERNEL_DIR" || exit
    make -j"$CORE" ${IMAGE_KERNEL} uImage vmlinux dtbs LOADADDR=0xC2000040 O="${OUTPUT_BUILD_DIR}"
    cd - || exit
}

build_modules() {
    cd "$KERNEL_DIR" || exit
    make -j"$CORE" modules O="${OUTPUT_BUILD_DIR}"
    cd - || exit
}

install_artifacts() {
    cd "$KERNEL_DIR" || exit
    make -j"$CORE" INSTALL_MOD_PATH="${ARTIFACT_DIR}" modules_install O="${OUTPUT_BUILD_DIR}"
    cd - || exit

    mkdir -p "${BOOT_DIR}"
    cp "${OUTPUT_BUILD_DIR}/arch/${ARCH}/boot/${IMAGE_KERNEL}" "${BOOT_DIR}/"
    find "${OUTPUT_BUILD_DIR}/arch/${ARCH}/boot/dts/" -name 'stm32mp157*.dtb' -exec cp '{}' "${BOOT_DIR}/" \;
}

deploy_kernel_to_board() {
    if [[ -z "$IP" ]]; then
        echo "Board IP not set."
        exit 1
    fi

    echo "Deploying to board at $IP..."
    cd "${ARTIFACT_DIR}" || exit 1

    echo "Cleaning symlinks..."
    unlink "${MODULES_DIR}/build" 2>/dev/null
    unlink "${MODULES_DIR}/source" 2>/dev/null

    echo "Copying uImage and DTBs..."
    rsync -avz --progress ${BOOT_DIR}/uImage root@"$IP":/boot/
    rsync -avz --progress ${BOOT_DIR}/stm32mp157*.dtb root@"$IP":/boot/

    echo "Syncing modules..."
    rsync -avz --delete --progress "lib/modules/${KERNEL_VERSION}" root@"$IP":/lib/modules/

    echo "Running depmod on board..."
    ssh root@"$IP" "depmod -a ${KERNEL_VERSION}; sync"

    echo "Deployment complete."
}

print_help() {
    echo "Usage: $0 <option>"
    echo
    echo "Options:"
    echo "  def     -> Run defconfig and setup .config"
    echo "  menu    -> Run menuconfig"
    echo "  b       -> Build kernel and modules"
    echo "  ia      -> Install artifacts"
    echo "  cp      -> Deploy to STM32MP board over SSH"
    echo
}

# === MAIN ENTRY ===
check_toolchain

case "$OPT" in
  def)
    defconfig
    ;;
  menu)
    menuconfig
    ;;
  b)
    build_kernel
    build_modules
    install_artifacts
    ;;
  ia)
    install_artifacts
    ;;
  cp)
    deploy_kernel_to_board
    ;;
  *)
    print_help
    ;;
esac

