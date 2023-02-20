#! /bin/bash

#
# Script for building Android arm64 Kernel
#
# Copyright (c) 2022 Wimbi Yoas Hizkia <wimbiyoashizkia@yahoo.com>
# Based on Panchajanya1999 script.
#

# Function to show an informational message
msg() {
	echo -e "\e[1;32m$*\e[0m"
}

err() {
	echo -e "\e[1;41m$*\e[0m"
	exit 1
}

# Set environment for directory
KERNEL_DIR=$PWD
IMG_DIR="$KERNEL_DIR"/out/arch/arm64/boot

# Get defconfig file
DEFCONFIG=munch_defconfig

# Set common environment
export KBUILD_BUILD_USER="wimbiyoas"

# Get distro name
DISTRO=$(source /etc/os-release && echo ${NAME})

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Set date and time
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d - %H:%M")

# Get branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
export BRANCH

# Check kernel version
KERVER=$(make kernelversion)

# Get last commit
COMMIT_HEAD=$(git log --oneline -1)

# Set enviroment for naming kernel
DEVICE="POCO F4"
CODENAME="MUNCH"
KERNEL="NEON"
KERNELTYPE="v4.19"

# Set environment for telegram
export CHATID="-1001520174422"
export token="1686322470:AAGXAiglWR8ktsqyjwPx4AXr66LZjWoQt80"
export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
export KBUILD_BUILD_HOST="FX505DD"

# Set function for telegram
tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

tg_post_build() {
	# Post MD5 Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	# Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

# Set function for cloning repository
clone() {
	# Clone Proton clang
	git clone --depth=1 https://github.com/kdrag0n/proton-clang clang
	# Set environment for clang
	TC_DIR=$KERNEL_DIR/clang
	# Get path and compiler string
	KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	PATH=$TC_DIR/bin/:$PATH
	export LD_LIBRARY_PATH=$TC_DIR/bin/:$LD_LIBRARY_PATH
	export PATH KBUILD_COMPILER_STRING
}

# Set function for naming zip file
set_naming() {
	KERNELNAME="$KERNEL-$CODENAME-$KERNELTYPE-$DATE"
	export KERNELTYPE KERNELNAME
	export ZIP_NAME="$KERNELNAME.zip"
}

# Set function for starting compile
compile() {
	# Clone AnyKernel3
	git clone --depth=1 https://github.com/neonproject-org/AnyKernel3.git -b master

	echo -e "Kernel compilation starting"

	tg_post_msg "<b>Docker OS	: </b><code>$DISTRO</code>%0A<b>Pipeline Host	: </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count	: </b><code>$PROCS</code>%0A<b>Device	: </b><code>$DEVICE [$CODENAME]</code>%0A<b>Branch	: </b><code>$BRANCH</code>%0A<b>Kernel Version	: </b><code>$KERVER</code>%0A<b>Compiler Used	: </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Date	: </b><code>$DATE</code>%0A<b>Last Commit	: </b><code>$COMMIT_HEAD</code>"

	make O=out "$DEFCONFIG"

	BUILD_START=$(date +"%s")

	make -j"$PROCS" O=out \
					CROSS_COMPILE=aarch64-linux-gnu- \
					LLVM=1

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [ -f "$IMG_DIR"/Image ]; then
		echo -e "Kernel successfully compiled"
	elif ! [ -f "$IMG_DIR"/Image ]; then
		echo -e "Kernel compilation failed"
		tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
		exit 1
	fi
}

# Set function for zipping into a flashable zip
gen_zip() {
	# Clean kernel image, dtbo & zip on AnyKernel3
	cd AnyKernel3 || exit
	rm -rf dtb dtbo.img Image *.zip
	cd ..

	# Move kernel image to AnyKernel3
	mv "$IMG_DIR"/Image.gz AnyKernel3/Image.gz
	mv "$IMG_DIR"/dtbo.img AnyKernel3/dtbo.img
	cd AnyKernel3 || exit

	# Archive to flashable zip
	zip -r9 "$ZIP_NAME" * -x .git README.md *.zip

	# Prepare a final zip variable
	ZIP_FINAL="$ZIP_NAME"

	tg_post_build "$ZIP_FINAL" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"

	cd ..
}

clone
compile
set_naming
gen_zip
