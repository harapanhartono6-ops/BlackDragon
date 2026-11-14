#!/bin/bash

# ============================================================
# Verification Script - Check BakaSU+SUSFS Integration
# ============================================================

echo "🔍 Verifying Neko Kernel BakaSU+SUSFS Integration"
echo "=================================================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check file/directory
check_exists() {
    if [ -e "$1" ]; then
        echo "✅ $2"
        return 0
    else
        echo "❌ $2 - NOT FOUND: $1"
        ((ERRORS++))
        return 1
    fi
}

# Function to check config
check_config() {
    if grep -q "$1" "$2" 2>/dev/null; then
        echo "✅ Config $1 present in $2"
        return 0
    else
        echo "⚠️  Config $1 not found in $2"
        ((WARNINGS++))
        return 1
    fi
}

echo "📦 Checking BakaSU Integration..."
echo "-----------------------------------"
check_exists "BakaSU/" "BakaSU kernel module directory"
check_exists "BakaSU/Kconfig" "BakaSU Kconfig"
check_exists "BakaSU/Makefile" "BakaSU Makefile"
check_exists "drivers/bakasu" "BakaSU symlink in drivers/"
check_config "obj-\$(CONFIG_BAKASU) += bakasu/" "drivers/Makefile"
check_config "source \"drivers/bakasu/Kconfig\"" "drivers/Kconfig"
echo ""

echo "🔒 Checking SUSFS Integration..."
echo "-----------------------------------"
check_exists "fs/susfs.c" "SUSFS source file"
check_exists "include/linux/susfs.h" "SUSFS header file"
echo ""

echo "⚙️  Checking Kernel Configuration..."
echo "-----------------------------------"
DEFCONFIG="arch/arm64/configs/vendor/atoll_defconfig"
check_config "CONFIG_BAKASU=y" "$DEFCONFIG"
check_config "CONFIG_BAKASU_SUSFS=y" "$DEFCONFIG"
check_config "CONFIG_BAKASU_SUSFS_SUS_SU=y" "$DEFCONFIG"
check_config "CONFIG_BAKASU_SUSFS_SUS_PATH=y" "$DEFCONFIG"
echo ""

echo "🔨 Checking Build Scripts..."
echo "-----------------------------------"
check_exists "setup_bakasu_susfs.sh" "BakaSU+SUSFS setup script"
check_exists "build_with_neutron.sh" "Neutron Clang build script"
check_exists ".github/workflows/build-kernel.yml" "GitHub Actions workflow"
echo ""

echo "📚 Checking Documentation..."
echo "-----------------------------------"
check_exists "README_BAKASU.md" "BakaSU README"
check_exists "SETUP_GUIDE.md" "Setup guide"
echo ""

echo "🔧 Checking Build Dependencies..."
echo "-----------------------------------"
if [ -d ~/toolchains/neutron-clang-24 ]; then
    echo "✅ Neutron Clang 24 installed at ~/toolchains/neutron-clang-24"
else
    echo "⚠️  Neutron Clang 24 not found (needed for local build only)"
    ((WARNINGS++))
fi

if [ -d ~/AnyKernel3 ]; then
    echo "✅ AnyKernel3 found at ~/AnyKernel3"
else
    echo "⚠️  AnyKernel3 not found (will be cloned during build)"
    ((WARNINGS++))
fi

if command -v ccache &> /dev/null; then
    echo "✅ ccache installed (build acceleration enabled)"
else
    echo "⚠️  ccache not installed (optional, improves rebuild speed)"
    ((WARNINGS++))
fi
echo ""

echo "📋 Summary"
echo "=================================================="
if [ $ERRORS -eq 0 ]; then
    echo "✅ All critical checks passed!"
    echo "✅ Kernel is ready to build"
    
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  $WARNINGS warning(s) found (non-critical)"
    fi
    
    echo ""
    echo "🚀 Next Steps:"
    echo "   For GitHub Actions build:"
    echo "     git add ."
    echo "     git commit -m 'Add BakaSU+SUSFS integration'"
    echo "     git push origin Neko-Baka"
    echo ""
    echo "   For local build:"
    echo "     ./build_with_neutron.sh"
    echo ""
    exit 0
else
    echo "❌ $ERRORS error(s) found!"
    echo "⚠️  $WARNINGS warning(s) found"
    echo ""
    echo "Please fix the errors before building."
    echo "Run './setup_bakasu_susfs.sh' if integration is incomplete."
    exit 1
fi
