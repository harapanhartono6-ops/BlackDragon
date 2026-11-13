#!/sbin/sh
# Neko-Kernel AnyKernel3 for realme 6 Pro (RMX2061)
# With BakaSU + SUSFS integration

# Disk space check
# space_action() = leave as default

# RAM disk compression
# ramdisk_compression = auto

# Patch v1-v2
do.devicecheck() {
    # Match devices for realme 6 Pro (RMX2061)
    # MT6785 / Helio G90T
    if [ "$(getprop ro.product.device)" = "RMX2061" ] || \
       [ "$(getprop ro.build.product)" = "RMX2061" ] || \
       [ "$(getprop ro.product.model)" = "realme 6 Pro" ]; then
        return 0
    fi
    return 1
}

# Install ramdisk
do.install() {
    # Backup stock boot.img
    # (AnyKernel3 handles this automatically)
    
    # Patch boot.img
    patch_boot_image
    
    # Write boot image
    write_boot
    
    # Install modules if any
    # (BakaSU modules would go here if needed)
}

# End install
do.cleanup() {
    # Clean up any temporary files
    rm -rf /tmp/anykernel 2>/dev/null
}

# Call the functions
# AnyKernel3 will call these automatically
