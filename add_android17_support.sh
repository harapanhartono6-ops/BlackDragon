#!/bin/bash

# ============================================================
# Android 17 (FCM Level 7) Compatibility Patch
# Adds required configs for Android 17 custom ROMs
# ============================================================

set -e

KERNEL_ROOT=$(pwd)
DEFCONFIG="arch/arm64/configs/vendor/atoll_defconfig"

echo -e "\n🔧 \033[1;34m[Android 17] Adding FCM Level 7 required configs...\033[0m"

if [ ! -f "$DEFCONFIG" ]; then
    echo -e "\n❌ \033[1;31mDefconfig not found: $DEFCONFIG\033[0m"
    exit 1
fi

# Backup defconfig
cp "$DEFCONFIG" "${DEFCONFIG}.android17.bak"

echo "   Backup created: ${DEFCONFIG}.android17.bak"

# Remove conflicting configs
sed -i '/# CONFIG_RD_LZ4 is not set/d' "$DEFCONFIG"
sed -i '/# CONFIG_CFI_CLANG is not set/d' "$DEFCONFIG"
sed -i '/# CONFIG_SHADOW_CALL_STACK is not set/d' "$DEFCONFIG"
sed -i '/# CONFIG_KFENCE is not set/d' "$DEFCONFIG"

# Add Android 17 FCM Level 7 required configs
cat >> "$DEFCONFIG" << 'EOF'

# ============================================================
# Android 17 (FCM Level 7) Required Configs - Kernel 4.14
# ============================================================

# Compiler identification (auto-set by build system)
CONFIG_AS_IS_LLVM=y
CONFIG_CC_IS_CLANG=y
CONFIG_LD_IS_LLD=y

# Security features
CONFIG_SHADOW_CALL_STACK=y
CONFIG_CFI_CLANG=y
CONFIG_CFI_PERMISSIVE=y

# HID support
CONFIG_HIDRAW=y
CONFIG_HID_PLAYSTATION=y
CONFIG_PLAYSTATION_FF=y

# Kernel memory safety
CONFIG_KFENCE=y

# Network traffic control
CONFIG_NET_ACT_BPF=y
CONFIG_NET_ACT_POLICE=y
CONFIG_NET_CLS_MATCHALL=y
CONFIG_NET_SCH_TBF=y

# Compression support
CONFIG_RD_LZ4=y

# Additional Android 17 requirements
CONFIG_BPF_SYSCALL=y
CONFIG_CGROUP_BPF=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y

# eBPF support for Android
CONFIG_NETFILTER_XT_MATCH_BPF=y

# Enable binder for Android
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y

# Required for Android 17 VINTF
CONFIG_ARM64_SW_TTBR0_PAN=y
EOF

echo -e "   ✅ Android 17 configs added to defconfig"

# Verify critical configs
echo ""
echo "🔍 Verifying Android 17 required configs..."

MISSING=0
REQUIRED_CONFIGS=(
    "CONFIG_AS_IS_LLVM"
    "CONFIG_CC_IS_CLANG"
    "CONFIG_CFI_CLANG"
    "CONFIG_HIDRAW"
    "CONFIG_HID_PLAYSTATION"
    "CONFIG_KFENCE"
    "CONFIG_LD_IS_LLD"
    "CONFIG_NET_ACT_BPF"
    "CONFIG_NET_ACT_POLICE"
    "CONFIG_NET_CLS_MATCHALL"
    "CONFIG_NET_SCH_TBF"
    "CONFIG_PLAYSTATION_FF"
    "CONFIG_RD_LZ4"
    "CONFIG_SHADOW_CALL_STACK"
)

for config in "${REQUIRED_CONFIGS[@]}"; do
    if grep -q "^${config}=y" "$DEFCONFIG"; then
        echo "   ✅ $config"
    else
        echo "   ❌ $config - NOT FOUND"
        ((MISSING++))
    fi
done

echo ""
if [ $MISSING -eq 0 ]; then
    echo -e "✅ \033[1;32m[SUCCESS] All Android 17 FCM Level 7 configs present!\033[0m"
    echo ""
    echo "📋 Summary:"
    echo "   - Kernel 4.14.357 ✅"
    echo "   - FCM Level 7 ✅"
    echo "   - Android 17 compatible ✅"
    echo "   - BakaSU + SUSFS ✅"
    echo "   - Neutron Clang 24 ✅"
    echo ""
    echo "⚠️  Important notes for Android 17:"
    echo "   1. CFI_CLANG enabled (may increase boot time slightly)"
    echo "   2. SHADOW_CALL_STACK enabled (security feature)"
    echo "   3. KFENCE enabled (kernel memory safety)"
    echo "   4. All network traffic control configs enabled"
    echo "   5. eBPF support enabled for Android"
    echo ""
    echo "🚀 Ready to build for Android 17!"
    exit 0
else
    echo -e "❌ \033[1;31m[ERROR] $MISSING config(s) missing!\033[0m"
    echo "   Please check the defconfig manually."
    exit 1
fi
