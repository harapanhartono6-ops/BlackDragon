#!/bin/bash

# ============================================================
# Alternative Build Script with Neutron Clang 24
# For local building (non-GitHub Actions)
# ============================================================

set -e

KERNEL_NAME="Neko-Kernel-BakaSU"
DEVICE="RMX2061"
VARIANT="BakaSU-SUSFS"
DEFCONFIG="vendor/atoll_defconfig"

DATE=$(date +%Y%m%d)
TIME=$(date +%H%M)
ZIPNAME="${KERNEL_NAME}-${DEVICE}-${VARIANT}-${TIME}-${DATE}.zip"

# Paths
KERNEL_ROOT=$(pwd)
CLANG_PATH=~/toolchains/neutron-clang-24
ANYKERNEL_DIR=~/AnyKernel3
OUT_DIR=out

export PATH=$CLANG_PATH/bin:$PATH
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=Neko
export KBUILD_BUILD_HOST=BakaSU

# Setup ccache if available
if command -v ccache &> /dev/null; then
    export USE_CCACHE=1
    export CCACHE_DIR=~/.ccache
    ccache -M 8G
    echo "✅ ccache enabled"
fi

echo -e "\n🚀 \033[1;34mStarting Neko Kernel Build with BakaSU+SUSFS\033[0m"

# ============================================================
# Check Prerequisites
# ============================================================

echo -e "\n🔍 \033[1;36mChecking prerequisites...\033[0m"

if [ ! -d "$CLANG_PATH" ]; then
    echo -e "\n❌ \033[1;31mNeutron Clang 24 not found at $CLANG_PATH\033[0m"
    echo "Please download it first:"
    echo "  mkdir -p ~/toolchains && cd ~/toolchains"
    echo "  wget https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/latest/download/neutron-clang-24-aarch64-linux-gnu.tar.zst"
    echo "  tar -I zstd -xf neutron-clang-24-aarch64-linux-gnu.tar.zst"
    echo "  mv neutron-clang neutron-clang-24"
    exit 1
fi

if [ ! -d "BakaSU" ]; then
    echo -e "\n⚠️  \033[1;33mBakaSU not integrated. Run ./setup_bakasu_susfs.sh first\033[0m"
    exit 1
fi

echo -e "   ✅ Neutron Clang 24 found"
echo -e "   ✅ BakaSU integrated"

# ============================================================
# Show Compiler Info
# ============================================================

echo -e "\n🔧 \033[1;36mCompiler Information:\033[0m"
clang --version | head -n 1
echo ""

# ============================================================
# Clean Previous Build
# ============================================================

echo -e "\n🧹 \033[1;33mCleaning previous build...\033[0m"
rm -rf $OUT_DIR
mkdir -p $OUT_DIR

if [ -d "$ANYKERNEL_DIR" ]; then
    rm -f "$ANYKERNEL_DIR/Image.gz-dtb"
    rm -f "$ANYKERNEL_DIR/Image.gz"
    rm -f "$ANYKERNEL_DIR"/*.zip
fi

# ============================================================
# Generate Defconfig
# ============================================================

echo -e "\n📄 \033[1;36mGenerating defconfig...\033[0m"

make O=$OUT_DIR ARCH=$ARCH LLVM=1 LLVM_IAS=1 $DEFCONFIG

if [ $? -ne 0 ]; then
    echo -e "\n❌ \033[1;31mDefconfig generation failed!\033[0m"
    exit 1
fi

# Verify BakaSU is enabled
if grep -q "CONFIG_BAKASU=y" "$OUT_DIR/.config"; then
    echo -e "   ✅ BakaSU is enabled in config"
else
    echo -e "   ❌ \033[1;31mBakaSU is not enabled in config!\033[0m"
    exit 1
fi

# ============================================================
# Build Kernel
# ============================================================

echo -e "\n🚀 \033[1;35mStarting kernel compilation...\033[0m"
echo -e "   Using $(nproc) threads"

START_TIME=$(date +%s)

make -j$(nproc) O=$OUT_DIR \
    ARCH=$ARCH \
    LLVM=1 \
    LLVM_IAS=1 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    2>&1 | tee $OUT_DIR/build.log | grep --line-buffered -E \
    "warning:|error:|fatal:|Killed|No space|Segmentation fault" | sed \
    -e 's/warning:/\x1b[1;33mwarning:\x1b[0m/g' \
    -e 's/error:/\x1b[1;31merror:\x1b[0m/g'

BUILD_STATUS=${PIPESTATUS[0]}
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

if [ "$BUILD_STATUS" -ne 0 ]; then
    echo -e "\n❌ \033[1;31mKernel compilation failed!\033[0m"
    echo "Check $OUT_DIR/build.log for details"
    exit "$BUILD_STATUS"
fi

# Show ccache stats if available
if command -v ccache &> /dev/null; then
    echo -e "\n📊 \033[1;36mccache statistics:\033[0m"
    ccache -s | grep -E "cache hit|cache miss|cache size"
fi

echo -e "\n✅ \033[1;32mKernel compiled in $(($BUILD_TIME / 60))m $(($BUILD_TIME % 60))s\033[0m"

# ============================================================
# Check Output
# ============================================================

KERNEL_IMG=""

if [ -f "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" ]; then
    KERNEL_IMG="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    echo -e "   ✅ Found Image.gz-dtb"
elif [ -f "$OUT_DIR/arch/arm64/boot/Image.gz" ]; then
    KERNEL_IMG="$OUT_DIR/arch/arm64/boot/Image.gz"
    echo -e "   ✅ Found Image.gz"
else
    echo -e "\n❌ \033[1;31mKernel image not found!\033[0m"
    exit 1
fi

ls -lh "$KERNEL_IMG"

# ============================================================
# Package with AnyKernel3
# ============================================================

echo -e "\n📦 \033[1;34mPackaging kernel...\033[0m"

if [ ! -d "$ANYKERNEL_DIR" ]; then
    echo "   Cloning AnyKernel3..."
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
fi

cd "$ANYKERNEL_DIR" || exit 1

# Update anykernel.sh
cat > anykernel.sh << 'EOF'
# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Neko Kernel with BakaSU+SUSFS by Neko-Baka
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=RMX2061
device.name2=RMX2063
device.name3=
device.name4=
device.name5=
supported.versions=10 - 14
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel install
dump_boot;
write_boot;
## end install
EOF

# Copy kernel image
if [[ "$KERNEL_IMG" == *"Image.gz-dtb"* ]]; then
    cp "$KERNEL_IMG" Image.gz-dtb
elif [[ "$KERNEL_IMG" == *"Image.gz"* ]]; then
    cp "$KERNEL_IMG" Image.gz
fi

# Copy dtb/dtbo if exists
if [ -f "$KERNEL_ROOT/$OUT_DIR/arch/arm64/boot/dtb.img" ]; then
    cp "$KERNEL_ROOT/$OUT_DIR/arch/arm64/boot/dtb.img" .
fi

if [ -f "$KERNEL_ROOT/$OUT_DIR/arch/arm64/boot/dtbo.img" ]; then
    cp "$KERNEL_ROOT/$OUT_DIR/arch/arm64/boot/dtbo.img" .
fi

# Create ZIP
echo -e "   Creating flashable ZIP..."
zip -r9 "$ZIPNAME" * -x .git README.md .gitignore .github placeholder > /dev/null

if [ $? -eq 0 ]; then
    echo -e "\n🎉 \033[1;32mFlashable ZIP created successfully!\033[0m"
    echo -e "   📦 File: $ANYKERNEL_DIR/$ZIPNAME"
    ls -lh "$ZIPNAME"
else
    echo -e "\n❌ \033[1;31mFailed to create ZIP!\033[0m"
    exit 1
fi

# ============================================================
# Summary
# ============================================================

echo -e "\n" 
echo -e "╔════════════════════════════════════════════════════════════╗"
echo -e "║          \033[1;32m✅ BUILD COMPLETED SUCCESSFULLY!\033[0m                ║"
echo -e "╠════════════════════════════════════════════════════════════╣"
echo -e "║  Kernel: ${KERNEL_NAME}                                    "
echo -e "║  Device: ${DEVICE}                                         "
echo -e "║  Build Time: $(($BUILD_TIME / 60))m $(($BUILD_TIME % 60))s                                       "
echo -e "║  Compiler: Neutron Clang 24                                "
echo -e "║  Features: BakaSU + SUSFS                                  "
echo -e "╠════════════════════════════════════════════════════════════╣"
echo -e "║  📦 Flashable ZIP:                                         "
echo -e "║     $ANYKERNEL_DIR/$ZIPNAME"
echo -e "╠════════════════════════════════════════════════════════════╣"
echo -e "║  📋 Installation:                                          "
echo -e "║     1. Boot to recovery (TWRP/OrangeFox)                   "
echo -e "║     2. Flash the ZIP file                                  "
echo -e "║     3. Reboot system                                       "
echo -e "║     4. Install BakaSU Manager APK                          "
echo -e "╚════════════════════════════════════════════════════════════╝"
echo -e "\n"
