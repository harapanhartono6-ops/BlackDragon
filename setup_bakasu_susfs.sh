#!/bin/bash

# ============================================================
# BakaSU + SUSFS Integration Script for Neko Kernel
# Realme 6 Pro (RMX2061) - Kernel 4.14
# ============================================================

set -e

KERNEL_ROOT=$(pwd)
BAKASU_DIR="../BakaSU"
SUSFS_DIR="../susfs4ksu"

echo -e "\n🚀 \033[1;34m[BakaSU+SUSFS] Starting integration...\033[0m"

# ============================================================
# Step 1: Setup BakaSU (KernelSU fork)
# ============================================================

if [ ! -d "$BAKASU_DIR" ]; then
    echo -e "\n❌ \033[1;31mBakaSU directory not found at $BAKASU_DIR\033[0m"
    exit 1
fi

echo -e "\n📦 \033[1;36m[Step 1/5] Setting up BakaSU...\033[0m"

# Clone/copy BakaSU kernel module
if [ ! -d "BakaSU" ]; then
    echo "   Copying BakaSU kernel module..."
    cp -r "$BAKASU_DIR/kernel" BakaSU
else
    echo "   BakaSU directory already exists, updating..."
    rm -rf BakaSU
    cp -r "$BAKASU_DIR/kernel" BakaSU
fi

# Create symlink in drivers
if [ -L "drivers/bakasu" ]; then
    rm drivers/bakasu
fi
ln -sf "../BakaSU" drivers/bakasu

echo -e "   ✅ BakaSU kernel module copied"

# ============================================================
# Step 2: Setup SUSFS patches for kernel 4.14
# ============================================================

echo -e "\n📦 \033[1;36m[Step 2/5] Setting up SUSFS...\033[0m"

if [ ! -d "$SUSFS_DIR" ]; then
    echo -e "\n❌ \033[1;31mSUSFS directory not found at $SUSFS_DIR\033[0m"
    exit 1
fi

# Copy SUSFS files
echo "   Copying SUSFS source files..."
cp "$SUSFS_DIR/kernel_patches/fs/susfs.c" fs/
cp "$SUSFS_DIR/kernel_patches/include/linux/susfs.h" include/linux/

echo -e "   ✅ SUSFS files copied"

# ============================================================
# Step 3: Apply BakaSU patches to drivers/Makefile and Kconfig
# ============================================================

echo -e "\n🔧 \033[1;36m[Step 3/5] Patching drivers/Makefile and Kconfig...\033[0m"

# Backup original files
cp drivers/Makefile drivers/Makefile.bak
cp drivers/Kconfig drivers/Kconfig.bak

# Add BakaSU to drivers/Makefile
if ! grep -q "obj-\$(CONFIG_BAKASU) += bakasu/" drivers/Makefile; then
    echo 'obj-$(CONFIG_BAKASU) += bakasu/' >> drivers/Makefile
    echo "   ✅ Added BakaSU to drivers/Makefile"
else
    echo "   ⚠️  BakaSU already in drivers/Makefile"
fi

# Add BakaSU to drivers/Kconfig
if ! grep -q "source \"drivers/bakasu/Kconfig\"" drivers/Kconfig; then
    # Add before endmenu
    sed -i '/^endmenu/i source "drivers/bakasu/Kconfig"' drivers/Kconfig
    echo "   ✅ Added BakaSU to drivers/Kconfig"
else
    echo "   ⚠️  BakaSU already in drivers/Kconfig"
fi

# ============================================================
# Step 4: Apply SUSFS kernel patches for 4.14
# ============================================================

echo -e "\n🔧 \033[1;36m[Step 4/5] Applying SUSFS kernel patches...\033[0m"

# Apply SUSFS patch for kernel 4.14
if [ -f "$SUSFS_DIR/kernel_patches/50_add_susfs_in_kernel-4.14.patch" ]; then
    echo "   Applying SUSFS 4.14 patch..."
    
    # Try to apply patch
    if patch -p1 --dry-run < "$SUSFS_DIR/kernel_patches/50_add_susfs_in_kernel-4.14.patch" > /dev/null 2>&1; then
        patch -p1 < "$SUSFS_DIR/kernel_patches/50_add_susfs_in_kernel-4.14.patch"
        echo -e "   ✅ SUSFS patch applied successfully"
    else
        echo -e "   ⚠️  \033[1;33mSUSFS patch has conflicts, may need manual merge\033[0m"
        echo "   Patch file: $SUSFS_DIR/kernel_patches/50_add_susfs_in_kernel-4.14.patch"
    fi
else
    echo -e "   ❌ \033[1;31mSUSFS 4.14 patch not found!\033[0m"
fi

# Apply SUSFS patch to BakaSU
if [ -f "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" ]; then
    echo "   Applying SUSFS patch to BakaSU..."
    cd BakaSU
    if patch -p1 --dry-run < "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" > /dev/null 2>&1; then
        patch -p1 < "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
        echo -e "   ✅ BakaSU SUSFS patch applied successfully"
    else
        echo -e "   ⚠️  \033[1;33mBakaSU SUSFS patch has conflicts\033[0m"
    fi
    cd "$KERNEL_ROOT"
fi

# ============================================================
# Step 5: Update defconfig
# ============================================================

echo -e "\n🔧 \033[1;36m[Step 5/5] Updating kernel defconfig...\033[0m"

DEFCONFIG="arch/arm64/configs/vendor/atoll_defconfig"

# Backup defconfig
cp "$DEFCONFIG" "${DEFCONFIG}.bak"

# Add BakaSU and SUSFS configs
cat >> "$DEFCONFIG" << 'EOF'

# BakaSU Configuration
CONFIG_BAKASU=y
CONFIG_BAKASU_DEBUG=y
CONFIG_BAKASU_SUSFS=y
CONFIG_BAKASU_SUSFS_SUS_SU=y
CONFIG_BAKASU_SUSFS_SUS_KSTAT=y
CONFIG_BAKASU_SUSFS_SUS_OVERLAYFS=y
CONFIG_BAKASU_SUSFS_TRY_UMOUNT=y
CONFIG_BAKASU_SUSFS_SPOOF_UNAME=y
CONFIG_BAKASU_SUSFS_ENABLE_LOG=y
CONFIG_BAKASU_SUSFS_OPEN_REDIRECT=y
CONFIG_BAKASU_SUSFS_SUS_PATH=y
CONFIG_BAKASU_SUSFS_SUS_MOUNT=y
EOF

echo -e "   ✅ Defconfig updated with BakaSU+SUSFS configs"

# ============================================================
# Summary
# ============================================================

echo -e "\n✅ \033[1;32m[SUCCESS] BakaSU+SUSFS integration completed!\033[0m"
echo ""
echo "📋 What was done:"
echo "   1. ✅ BakaSU kernel module integrated"
echo "   2. ✅ SUSFS source files copied"
echo "   3. ✅ Drivers Makefile and Kconfig patched"
echo "   4. ✅ SUSFS kernel patches applied"
echo "   5. ✅ Defconfig updated"
echo ""
echo "⚠️  Important notes:"
echo "   - Check if patches applied cleanly (look for warnings above)"
echo "   - Review the defconfig at: $DEFCONFIG"
echo "   - Backup files created with .bak extension"
echo ""
echo "🔨 Next steps:"
echo "   1. Review and adjust configs if needed"
echo "   2. Build the kernel using GitHub Actions"
echo "   3. Flash and test on your device"
echo ""
