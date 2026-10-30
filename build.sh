#!/usr/bin/env bash
#
# BlackDragon kernel build script
# Target: Realme 6 Pro (RMX2061 / atoll)
#
# IMPORTANT:
# BUILD_TYPE="BakaSU" below is only an artifact label. This script does NOT
# replace KSU-NEXT with BakaSU. The actual implementation is determined by
# the kernel source tree, its setup scripts, and atoll_defconfig.
#

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Paths and build settings
# ---------------------------------------------------------------------------

KERNEL_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLANG_DIR="${CLANG_DIR:-${HOME}/toolchains/clang}"
GCC_DIR="${GCC_DIR:-${HOME}/toolchains/gcc-aarch64-linux-gnu-9.3}"
ANYKERNEL_DIR="${ANYKERNEL_DIR:-${HOME}/AnyKernel3}"
OUT_DIR="${OUT_DIR:-out}"

KERNEL_NAME="-BlackDragon-@Kitshune-"
DEVICE="RMX2061"
VARIANT="perf"
BUILD_TYPE="BakaSU"       # Artifact label only; see IMPORTANT note above.
VERSION_NUMBER="v1.0.1"

DATE="$(date +%Y%m%d)"
TIME="$(date +%H%M)"
BASE_ZIPNAME="${KERNEL_NAME}-${VARIANT}-${DEVICE}-${BUILD_TYPE}-${TIME}-${DATE}-${VERSION_NUMBER}"
ZIPNAME="${BASE_ZIPNAME}.zip"

JOBS="${JOBS:-$(nproc)}"
BUILD_LOG="${OUT_DIR}/build.log"
KERNEL_IMG="${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"

export KERNEL_ROOT CLANG_PATH="$CLANG_DIR" GCC_PATH="$GCC_DIR"
export ANYKERNEL_DIR OUT_DIR
export ARCH=arm64
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-
export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
export PATH="${CLANG_DIR}/bin:${GCC_DIR}/bin:${PATH}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
    printf '\n❌ %s\n' "$*" >&2
    exit 1
}

log() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*"
}

clone_if_missing() {
    local directory="$1"
    local repository="$2"
    local branch="${3:-}"

    if [[ -d "$directory/.git" ]]; then
        printf '✅ Found %s\n' "$directory"
        return
    fi

    if [[ -e "$directory" ]]; then
        die "$directory exists but is not a Git repository. Move it or remove it, then retry."
    fi

    mkdir -p "$(dirname "$directory")"
    log "Cloning ${repository}"
    if [[ -n "$branch" ]]; then
        git clone --depth=1 --branch "$branch" "$repository" "$directory"
    else
        git clone --depth=1 "$repository" "$directory"
    fi
}

show_first_failure_context() {
    local failure_line context_start context_end

    [[ -f "$BUILD_LOG" ]] || return 0

    failure_line="$(
        grep -n -m1 -E \
            '(^|: )(fatal )?error:|fatal:|clang:.*(unable|crash)|make(\[[0-9]+\])?: \*\*\*' \
            "$BUILD_LOG" | cut -d: -f1 || true
    )"

    if [[ -n "$failure_line" ]]; then
        context_start=$(( failure_line > 40 ? failure_line - 40 : 1 ))
        context_end=$(( failure_line + 20 ))
        printf '\n🔎 First failure context from %s:\n' "$BUILD_LOG"
        sed -n "${context_start},${context_end}p" "$BUILD_LOG"
    else
        printf '\n⚠️ No compiler error pattern found. Inspect %s for the failure.\n' "$BUILD_LOG"
    fi
}

# ---------------------------------------------------------------------------
# Validate host and settings
# ---------------------------------------------------------------------------

for command_name in git make zip grep sed tee; do
    command -v "$command_name" >/dev/null 2>&1 ||
        die "Required command not found: $command_name"
done

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die "JOBS must be a positive integer (received: $JOBS)."

[[ -f "${KERNEL_ROOT}/Makefile" ]] || die "Kernel Makefile not found in ${KERNEL_ROOT}."
[[ -d "${KERNEL_ROOT}/arch/arm64/configs" ]] || die "ARM64 defconfig directory not found."
[[ -f "${KERNEL_ROOT}/arch/arm64/configs/atoll_defconfig" ]] ||
    die "atoll_defconfig not found."

# ---------------------------------------------------------------------------
# Fetch toolchains and AnyKernel3 if they are not already present
# ---------------------------------------------------------------------------

clone_if_missing "$CLANG_DIR" \
    "https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git" \
    "lineage-20.0"

clone_if_missing "$GCC_DIR" \
    "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-gnu-9.3.git" \
    "lineage-23.0"

clone_if_missing "$ANYKERNEL_DIR" \
    "https://github.com/theshaenix/AnyKernel3.git"

[[ -x "${CLANG_DIR}/bin/clang" ]] || die "Clang executable missing: ${CLANG_DIR}/bin/clang"
[[ -x "${GCC_DIR}/bin/aarch64-linux-gcc" ]] ||
    die "Cross GCC executable missing: ${GCC_DIR}/bin/aarch64-linux-gcc"
[[ -f "${ANYKERNEL_DIR}/anykernel.sh" ]] ||
    die "AnyKernel3 does not look valid: ${ANYKERNEL_DIR}/anykernel.sh not found"

# ---------------------------------------------------------------------------
# Start build
# ---------------------------------------------------------------------------

log "BlackDragon kernel build"
printf 'Device       : %s\n' "$DEVICE"
printf 'Variant      : %s\n' "$VARIANT"
printf 'Build label  : %s (label only; does not install BakaSU)\n' "$BUILD_TYPE"
printf 'Jobs         : %s\n' "$JOBS"
printf 'Kernel root  : %s\n' "$KERNEL_ROOT"
printf 'Output       : %s\n' "$OUT_DIR"

log "Compiler versions"
"${CLANG_DIR}/bin/clang" --version | head -n 1
"${GCC_DIR}/bin/aarch64-linux-gcc" --version | head -n 1

# Clean only the kernel output directory. Do not clear ccache: GitHub Actions
# can reuse it between runs.
log "Cleaning kernel output directory"
rm -rf -- "${KERNEL_ROOT:?}/${OUT_DIR}"
mkdir -p "${KERNEL_ROOT}/${OUT_DIR}"

cd "$KERNEL_ROOT"

# ---------------------------------------------------------------------------
# Defconfig
# ---------------------------------------------------------------------------

log "Generating atoll_defconfig"
make O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 atoll_defconfig

CONFIG_FILE="${OUT_DIR}/.config"
[[ -f "$CONFIG_FILE" ]] || die "Defconfig did not produce ${CONFIG_FILE}"

# Retain the checks present in the supplied build script.
required_configs=(
    CONFIG_AS_IS_LLVM
    CONFIG_CC_IS_CLANG
    CONFIG_CFI_CLANG
    CONFIG_HIDRAW
    CONFIG_HID_PLAYSTATION
    CONFIG_KFENCE
    CONFIG_LD_IS_LLD
    CONFIG_NET_ACT_BPF
    CONFIG_NET_ACT_POLICE
    CONFIG_NET_CLS_MATCHALL
    CONFIG_NET_SCH_TBF
    CONFIG_PLAYSTATION_FF
    CONFIG_RD_LZ4
    CONFIG_SHADOW_CALL_STACK
)

for config in "${required_configs[@]}"; do
    if ! grep -qx "${config}=y" "$CONFIG_FILE"; then
        die "Required kernel config missing or disabled: ${config}"
    fi
done

if ! grep -qx 'CONFIG_KSU=y' "$CONFIG_FILE"; then
    die "CONFIG_KSU=y is not enabled in the generated config."
fi

printf '\n⚠️ CONFIG_KSU=y is enabled, but this does not identify whether the source is KSU-NEXT or BakaSU.\n'
printf '   BakaSU integration must be verified in the kernel source/setup files before flashing.\n'

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------

log "Compiling kernel"
set +e
make -j"$JOBS" O="$OUT_DIR" \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CLANG_TRIPLE="$CLANG_TRIPLE" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    2>&1 | tee "$BUILD_LOG"
BUILD_STATUS="${PIPESTATUS[0]}"
set -e

if [[ "$BUILD_STATUS" -ne 0 ]]; then
    show_first_failure_context
    die "Kernel compilation failed with exit code ${BUILD_STATUS}. See ${BUILD_LOG}."
fi

# ---------------------------------------------------------------------------
# Verify image
# ---------------------------------------------------------------------------

[[ -s "$KERNEL_IMG" ]] ||
    die "Expected kernel image not found or empty: ${KERNEL_IMG}"

log "Kernel image compiled successfully"

# ---------------------------------------------------------------------------
# Package AnyKernel3 ZIP
# ---------------------------------------------------------------------------

log "Packaging flashable ZIP"

# Remove only previous BlackDragon ZIPs matching this naming scheme. Preserve
# unrelated ZIP files that may belong to the AnyKernel3 repository.
find "$ANYKERNEL_DIR" -maxdepth 1 -type f \
    -name "${KERNEL_NAME}-${VARIANT}-${DEVICE}-${BUILD_TYPE}-*.zip" \
    -delete

cp -- "$KERNEL_IMG" "${ANYKERNEL_DIR}/zImage"

(
    cd "$ANYKERNEL_DIR"
    zip -r9 "$ZIPNAME" . \
        -x "*.zip" \
        -x ".git/*" \
        -x "README.md"
)

ZIP_PATH="${ANYKERNEL_DIR}/${ZIPNAME}"
[[ -s "$ZIP_PATH" ]] || die "ZIP packaging failed: ${ZIP_PATH}"

printf '\n🎉 Flashable ZIP created:\n%s\n' "$ZIP_PATH"
printf 'Size: '
du -h "$ZIP_PATH" | awk '{print $1}'
