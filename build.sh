#!/bin/bash

# ============================================================
# Neko-Kernel Build Script for realme 6 Pro (RMX2061)
# With BakaSU + SUSFS integration and Neutron Clang 24
# ============================================================

# Paths
GCC_DIR=~/toolchains/gcc-aarch64-linux-gnu-9.3
ANYKERNEL_DIR=~/AnyKernel3

# Ensure we're in the kernel directory
KERNEL_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$KERNEL_ROOT" || exit 1

# Check if GCC cross-compiler is usable (must be aarch64-native)
GCC_CROSS_PREFIX="aarch64-buildroot-linux-gnu-"
if [ -f "$GCC_DIR/bin/${GCC_CROSS_PREFIX}gcc" ]; then
  if "$GCC_DIR/bin/${GCC_CROSS_PREFIX}gcc" --version >/dev/null 2>&1; then
    USE_CROSS_GCC=true
  else
    USE_CROSS_GCC=false
    echo -e "\n⚠️  \033[1;33mGCC cross-compiler binary not compatible with this host.\033[0m"
    echo -e "\033[1;33m   Will use native gcc instead.\033[0m"
  fi
else
  USE_CROSS_GCC=false
  echo -e "\n⚠️  \033[1;33mGCC cross-compiler not found.\033[0m"
  echo -e "\033[1;33m   Will use native gcc instead.\033[0m"
fi

# Check AnyKernel3
if [ ! -d "$ANYKERNEL_DIR" ]; then
  echo -e "\n🔍 \033[1;33mAnyKernel3 not found. Cloning...\033[0m"
  git clone --depth=1 https://github.com/theshaenix/AnyKernel3.git "$ANYKERNEL_DIR" 2>&1 || \
    echo -e "\033[1;33m⚠️  AnyKernel3 clone failed (network issue?).\033[0m"
else
  echo -e "\n✅ \033[1;32mAnyKernel3 folder already present.\033[0m"
fi

# ============================================================
# Build Script
# ============================================================

# Kernel build configuration
KERNEL_NAME="Neko-Kernel-"
DEVICE="RMX2061"
VARIANT="perf"
BUILD_TYPE="BakaSU"
VERSION_NUMBER="v1.0.0"

DATE=$(date +%Y%m%d)
TIME=$(date +%H%M)
BASE_ZIPNAME="${KERNEL_NAME}${VARIANT}-${DEVICE}-${BUILD_TYPE}-${TIME}-${DATE}-${VERSION_NUMBER}"
ZIPNAME="${BASE_ZIPNAME}.zip"

# Paths
export KERNEL_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export GCC_PATH=$GCC_DIR
export ANYKERNEL_DIR=$ANYKERNEL_DIR
export OUT_DIR=out

export ARCH=arm64
export SUBARCH=arm64

# Compiler setup: prefer native gcc (we're on aarch64 building for aarch64)
if $USE_CROSS_GCC; then
  export PATH=$GCC_PATH/bin:/usr/bin:/bin:$PATH
  export CROSS_COMPILE=$GCC_CROSS_PREFIX
  export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  export CC=$GCC_CROSS_PREFIX"gcc"
  export LD=$GCC_CROSS_PREFIX"ld"
  export AR=$GCC_CROSS_PREFIX"ar"
  export NM=$GCC_CROSS_PREFIX"nm"
  export OBJCOPY=$GCC_CROSS_PREFIX"objcopy"
  export OBJDUMP=$GCC_CROSS_PREFIX"objdump"
  export STRIP=$GCC_CROSS_PREFIX"strip"
  COMPILER_INFO="GCC cross ($($GCC_CROSS_PREFIX"gcc" --version 2>/dev/null | head -1))"
else
  # Native build - empty CROSS_COMPILE
  export PATH=/usr/bin:/bin:$PATH
  export CROSS_COMPILE=
  export CROSS_COMPILE_ARM32=
  export CC=gcc
  export LD=ld
  export AR=ar
  export NM=nm
  export OBJCOPY=objcopy
  export OBJDUMP=objdump
  export STRIP=strip
  COMPILER_INFO="GCC native (gcc $(gcc --version 2>/dev/null | head -1 | awk '{print $NF}'))"
fi

export HOSTCC=gcc
export HOSTCXX=g++
export LLVM=0
export LLVM_IAS=0
export HOSTCFLAGS="-Wno-error=format-security -Wno-builtin-declaration-mismatch"
unset CLANG_TRIPLE

# Allow constrained builders to lower parallelism without editing this script.
JOBS="${JOBS:-$(nproc)}"

# The filtered live output keeps routine builds readable, while build.log keeps
# the complete compiler output.  When a target fails, show the first failure
# and the preceding lines from that raw log; this is usually where clang (or a
# host tool) explains why the subsequent missing-object errors occurred.
show_first_failure_context() {
  local failure_line context_start context_end

  failure_line=$(grep -n -m1 -E \
    '(^|: )(fatal )?error:|fatal:|clang:.*(unable|crash)|make(\[[0-9]+\])?: \*\*\*' \
    "$OUT_DIR/build.log" | cut -d: -f1)

  if [ -n "$failure_line" ]; then
    context_start=$((failure_line > 40 ? failure_line - 40 : 1))
    context_end=$((failure_line + 20))
    echo -e "\n🔎 \033[1;36mFirst failure context from $OUT_DIR/build.log:\033[0m"
    sed -n "${context_start},${context_end}p" "$OUT_DIR/build.log"
  fi
}

# =====================[ START PROCESS ]=====================

echo -e "\n🛠️  \033[1;34mStarting Kernel Build: $BASE_ZIPNAME\033[0m"

echo -e "\n🧹 \033[1;33mCleaning output and ccache...\033[0m"
rm -rf $OUT_DIR/*
rm -f "$ANYKERNEL_DIR/zImage"
rm -f "$ANYKERNEL_DIR/Image.gz-dtb"
ccache -C > /dev/null 2>&1

echo -e "\n🔧 \033[1;36mCompiler Info:\033[0m"
echo -e "   $COMPILER_INFO"
echo -e "   CROSS_COMPILE=$CROSS_COMPILE"

echo -e "\n📱 \033[1;32mTarget Device: $DEVICE\033[0m"
echo -e "🧵 \033[1;36mParallel build jobs: $JOBS\033[0m"
echo -e "\033[1;32mRoot Solution: $BUILD_TYPE\033[0m"

# =====================[ DEFCONFIG ]=====================

echo -e "\n📄 \033[1;36mSetting up defconfig...\033[0m"
make O=$OUT_DIR ARCH=arm64 rmx2061_defconfig

if [ $? -ne 0 ]; then
  echo -e "\n❌ \033[1;31mDefconfig failed. Exiting.\033[0m"
  exit 1
fi

# Verify KSU is enabled
if ! grep -qx "CONFIG_KSU=y" "$OUT_DIR/.config"; then
  echo -e "\n❌ \033[1;31mCONFIG_KSU is not enabled in .config!\033[0m"
  exit 1
fi

if grep -qx "CONFIG_KSU_MANUAL_HOOK=y" "$OUT_DIR/.config"; then
  echo -e "\n✅ \033[1;32mCONFIG_KSU_MANUAL_HOOK is enabled.\033[0m"
else
  echo -e "\n⚠️  \033[1;33mCONFIG_KSU_MANUAL_HOOK is not enabled. BakaSU hooks may not work.\033[0m"
fi

# =====================[ COMPILING ]=====================

echo -e "\n🚀 \033[1;35mStarting compilation with $COMPILER_INFO...\033[0m"

# Build make arguments
MAKE_ARGS="-j$JOBS O=$OUT_DIR ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32"

make $MAKE_ARGS \
  2>&1 | tee out/build.log

BUILD_STATUS=${PIPESTATUS[0]}
if [ "$BUILD_STATUS" -ne 0 ]; then
  show_first_failure_context
  echo -e "\n❌ \033[1;31mKernel compilation failed (see $OUT_DIR/build.log).\033[0m"
  exit "$BUILD_STATUS"
fi

# =====================[ CHECK IMAGE ]=====================

KERNEL_IMG=$OUT_DIR/arch/arm64/boot/Image.gz-dtb
if [ ! -f "$KERNEL_IMG" ]; then
  # Try plain Image.gz
  KERNEL_IMG=$OUT_DIR/arch/arm64/boot/Image.gz
fi
if [ ! -f "$KERNEL_IMG" ]; then
  echo -e "\n❌ \033[1;31mBuild failed: Kernel image not found!\033[0m"
  exit 1
fi

echo -e "\n✅ \033[1;32mKernel image compiled successfully.\033[0m"

# =====================[ PACKAGING ]=====================

echo -e "\n📦 \033[1;34mPacking kernel into flashable zip...\033[0m"
cp "$KERNEL_IMG" "$ANYKERNEL_DIR/zImage"

cd $ANYKERNEL_DIR || exit 1
zip -r9 "$ZIPNAME" * -x "*.zip" "*.git*" README.md > /dev/null

if [ $? -eq 0 ]; then
  echo -e "\n🎉 \033[1;32mFlashable zip created: $ANYKERNEL_DIR/$ZIPNAME\033[0m"
else
  echo -e "\n❌ \033[1;31mFailed to create zip.\033[0m"
  exit 1
fi

echo -e "\n🏁 \033[1;34mBuild completed successfully!\033[0m"
echo -e "   Zip: $ANYKERNEL_DIR/$ZIPNAME"
echo -e "   Device: $DEVICE"
echo -e "   Compiler: $COMPILER_INFO"
echo -e "   Root: BakaSU"
