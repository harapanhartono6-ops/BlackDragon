# Quick Setup Guide - Neko Kernel BakaSU+SUSFS

## 📝 File Overview

### Setup Scripts
- `setup_bakasu_susfs.sh` - Integrates BakaSU and SUSFS into kernel source
- `build_with_neutron.sh` - Local build script with Neutron Clang 24
- `build.sh` - Original build script (legacy)

### GitHub Actions
- `.github/workflows/build-kernel.yml` - Automated build on GitHub

### Documentation
- `README_BAKASU.md` - Complete documentation

## 🚀 Quick Start

### Option 1: Build with GitHub Actions (Recommended)

1. **Fork or use your existing repo**
2. **Push changes to GitHub:**
   ```bash
   cd Neko-Kernel
   git add .
   git commit -m "Add BakaSU+SUSFS support with Neutron Clang 24"
   git push origin Neko-Baka
   ```
3. **GitHub Actions will automatically build the kernel**
4. **Download from Actions artifacts or Releases**

### Option 2: Local Build

1. **Setup BakaSU and SUSFS:**
   ```bash
   cd Neko-Kernel
   ./setup_bakasu_susfs.sh
   ```

2. **Download Neutron Clang 24:**
   ```bash
   mkdir -p ~/toolchains && cd ~/toolchains
   wget https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/latest/download/neutron-clang-24-aarch64-linux-gnu.tar.zst
   tar -I zstd -xf neutron-clang-24-aarch64-linux-gnu.tar.zst
   mv neutron-clang neutron-clang-24
   ```

3. **Build kernel:**
   ```bash
   cd ~/path/to/Neko-Kernel
   ./build_with_neutron.sh
   ```

4. **Find the flashable ZIP at:**
   ```
   ~/AnyKernel3/Neko-Kernel-BakaSU-*.zip
   ```

## 🔧 What Was Changed

### Kernel Source Integration
- ✅ BakaSU kernel module added to `drivers/bakasu/`
- ✅ SUSFS source files added (`fs/susfs.c`, `include/linux/susfs.h`)
- ✅ `drivers/Makefile` and `drivers/Kconfig` patched
- ✅ Defconfig updated with BakaSU+SUSFS configs

### Build Configuration
- ✅ Neutron Clang 24 as compiler
- ✅ LLVM toolchain (LLVM=1, LLVM_IAS=1)
- ✅ Optimized for arm64
- ✅ ccache support for faster rebuilds

### GitHub Actions
- ✅ Automated build on push
- ✅ Artifact upload (30 days retention)
- ✅ Automatic releases for main branch
- ✅ Build logs and debugging

## 📦 Build Artifacts

After build completes, you'll get:
- **Flashable ZIP** - Ready to flash via recovery
- **Kernel images** - Image.gz-dtb or Image.gz
- **DTB/DTBO** - If applicable

## ⚙️ Configuration Options

All BakaSU+SUSFS features are enabled by default:
```
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
```

To modify, edit: `arch/arm64/configs/vendor/atoll_defconfig`

## 🐛 Troubleshooting

### Build fails with "BakaSU not enabled"
```bash
# Re-run setup script
./setup_bakasu_susfs.sh

# Verify defconfig
grep CONFIG_BAKASU arch/arm64/configs/vendor/atoll_defconfig
```

### Clang not found
```bash
# Check PATH
echo $PATH | grep neutron-clang-24

# Verify installation
~/toolchains/neutron-clang-24/bin/clang --version
```

### Patch conflicts
Some patches may have conflicts. Check:
- `drivers/Makefile.bak`
- `drivers/Kconfig.bak`
- `arch/arm64/configs/vendor/atoll_defconfig.bak`

Apply manually if needed.

## 📱 Testing After Flash

1. **Reboot to system**
2. **Check BakaSU:**
   ```bash
   su -c "bakasu -v"
   ```
3. **Check SUSFS:**
   ```bash
   su -c "ksu_susfs"
   ```
4. **Install BakaSU Manager from:** https://github.com/Baka-SU/BakaSU/releases

## 🔄 Updating

To update BakaSU or SUSFS:
```bash
cd ~/workspace
rm -rf BakaSU susfs4ksu

# Re-clone latest versions
git clone --depth=1 https://github.com/Baka-SU/BakaSU.git
git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git

# Re-run setup
cd Neko-Kernel
./setup_bakasu_susfs.sh
```

## 📊 Build Time Estimates

- **GitHub Actions:** ~15-25 minutes
- **Local (16 cores, ccache):** ~5-10 minutes first build, ~2-3 minutes subsequent
- **Local (8 cores, no ccache):** ~15-20 minutes

## 🆘 Support

- **BakaSU Issues:** https://github.com/Baka-SU/BakaSU/issues
- **SUSFS Issues:** https://gitlab.com/simonpunk/susfs4ksu/-/issues
- **Kernel Issues:** Your repo issues
- **Telegram:** https://t.me/BakaSU_Grp

## ✅ Checklist Before Build

- [ ] BakaSU and SUSFS repos cloned
- [ ] `setup_bakasu_susfs.sh` executed successfully
- [ ] Neutron Clang 24 downloaded and extracted
- [ ] Defconfig contains BakaSU configs
- [ ] GitHub Actions workflow file in place
- [ ] All changes committed to git

## 🎯 Next Steps

1. Test build locally or via GitHub Actions
2. Flash on device and test functionality
3. Report issues if any
4. Share with community!

---

**Note:** This is experimental. Always backup before flashing!
