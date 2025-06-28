#compile kernel script

OPT=$1
IP="192.168.7.1"
KERNEL_DIR="linux-6.1.28"

CROSS_COMPILE="arm-ostl-linux-gnueabi-"
if ! command -v "${CROSS_COMPILE}gcc" &> /dev/null; then
    echo "Error: AArch64 toolchain (${CROSS_COMPILE}gcc) not found!"
    echo "Please enable environmet by mp2_set_env"
    exit 1
fi

#set build folder
export OUTPUT_BUILD_DIR=$PWD/build

#set imgtarget
[ "${ARCH}" = "arm" ] && imgtarget="uImage" || imgtarget="Image.gz"
export IMAGE_KERNEL=${imgtarget}

CORE=$((2*$(nproc)))

#get kernel version appeneded
CONFIG_LOCALVERSION=$(grep "^CONFIG_LOCALVERSION=" $OUTPUT_BUILD_DIR/.config | cut -d '"' -f2)

# If CONFIG_LOCALVERSION is unset or empty, default to an empty string
CONFIG_LOCALVERSION=${CONFIG_LOCALVERSION:-""}

echo "Kernel Local Version: $CONFIG_LOCALVERSION"


#all cd to linux and cd - are used to go in linux dir and exec commands only
function build_kernel() {
	cd $KERNEL_DIR
	make -j$CORE ${IMAGE_KERNEL} uImage vmlinux dtbs LOADADDR=0xC2000040 O="${OUTPUT_BUILD_DIR}"
    cd -
}

deploy_kernel_to_board() {
    local BOARD_IP="$1"
    local OUTPUT_DIR="${OUTPUT_BUILD_DIR}/install_artifact"
    local KERNEL_VERSION="${KERNEL_DIR#linux-}$CONFIG_LOCALVERSION"

    if [[ -z "$BOARD_IP" ]]; then
        echo "Usage: deploy_kernel_to_board <board_ip>"
        return 1
    fi

    echo "Deploying kernel and modules to $BOARD_IP..."

    # Change to the output directory
    cd "$OUTPUT_DIR" || { echo "Failed to change directory to $OUTPUT_DIR"; return 1; }

    # Copy boot files
    echo "Copying boot files..."
    scp -r boot/uImage root@"$BOARD_IP":/boot/
    scp -r boot/stm32mp157d-dk1* root@"$BOARD_IP":/boot/

    # Remove the 'build' link in modules directory
    echo "Removing build link..."
    unlink "lib/modules/${KERNEL_VERSION}/build"
    unlink "lib/modules/${KERNEL_VERSION}/source"

    # Strip kernel modules to reduce size
    #echo "Stripping kernel modules..."
    #find lib/modules/ -name "*.ko" | xargs "$STRIP" --strip-debug --remove-section=.comment --remove-section=.note --preserve-dates

    # Copy kernel modules
    echo "Copying kernel modules..."
    scp -r lib/modules/${KERNEL_VERSION} root@"$BOARD_IP":/lib/modules/
#rsync -avz --progress --checksum lib/modules/${KERNEL_VERSION} root@"$BOARD_IP":/lib/modules/

    # Regenerate module dependencies on the board
    echo "Regenerating module dependencies..."
    ssh root@"$BOARD_IP" "/sbin/depmod -a"

    # Sync to ensure all changes are written
    echo "Syncing filesystem..."
    ssh root@"$BOARD_IP" "sync"

    echo "Kernel and modules deployed successfully!"
}


function build_modules() {
	cd $KERNEL_DIR
	make -j$CORE modules O="${OUTPUT_BUILD_DIR}"
    cd -
}

function install_artifacts() {
	cd linux-6.6.48
	cd $KERNEL_DIR
	make -j$CORE INSTALL_MOD_PATH="${OUTPUT_BUILD_DIR}/install_artifact" modules_install O="${OUTPUT_BUILD_DIR}"
    cd -
	mkdir -p ${OUTPUT_BUILD_DIR}/install_artifact/boot/
	cp ${OUTPUT_BUILD_DIR}/arch/${ARCH}/boot/${IMAGE_KERNEL} ${OUTPUT_BUILD_DIR}/install_artifact/boot/
	find ${OUTPUT_BUILD_DIR}/arch/${ARCH}/boot/dts/ -name 'st*.dtb' -exec cp '{}' ${OUTPUT_BUILD_DIR}/install_artifact/boot/ \;
}

function defconfig() {
	rm -rf ${OUTPUT_BUILD_DIR}
	mkdir ${OUTPUT_BUILD_DIR}
    rm -rf $KERNEL_DIR
	tar xf $KERNEL_DIR.tar.xz
	cd $KERNEL_DIR
	for p in `ls -1 ../*.patch`; do patch -p1 < $p; done
	make -j$CORE O="${OUTPUT_BUILD_DIR}" multi_v7_defconfig fragment*.config
	for f in `ls -1 ../fragment*.config`; do scripts/kconfig/merge_config.sh -m -r -O ${OUTPUT_BUILD_DIR} ${OUTPUT_BUILD_DIR}/.config $f; done
	(yes '' || true) |  make oldconfig O="${OUTPUT_BUILD_DIR}"
}

function print_error() {
	echo "not proper input"
	echo ""
	echo "b 	-> build kernel, module and install artifacts"
	echo "menu  -> menuconfig"
	echo "def   -> defconfig"
	echo "ia    -> install artifacts"
	echo "cp    -> deploy_kernel_to_board"
}

case $OPT in
  b)
	build_kernel
	build_modules
	install_artifacts
   ;;
 menu)
	cd $KERNEL_DIR
	make -j$(nproc) O=${OUTPUT_BUILD_DIR} menuconfig
    cd -
   ;;
 def)
	defconfig
   ;;
 ia)
    install_artifacts	
   ;;
 cp)
    deploy_kernel_to_board $IP $CONFIG_LOCALVERSION
    ;;
 *)
	print_error
   ;;
esac

