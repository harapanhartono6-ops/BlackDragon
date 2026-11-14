# Neko Kernel - BakaSU + SUSFS Edition

Kernel kustom untuk Realme 6 Pro (RMX2061/RMX2063) dengan integrasi BakaSU dan SUSFS.

## 🌟 Fitur

- ✅ **BakaSU** - Fork dari KernelSU dengan fitur tambahan
- ✅ **SUSFS** - Advanced root hiding untuk bypass SafetyNet/Play Integrity
- ✅ **Neutron Clang 24** - Compiled dengan compiler terbaru untuk performa optimal
- ✅ **GitHub Actions** - Automated build system
- ✅ **Kernel 4.14.357** - Base kernel stable

## 🔧 Spesifikasi Build

- **Device:** Realme 6 Pro (RMX2061/RMX2063)
- **Kernel Version:** 4.14.357
- **Compiler:** Neutron Clang 24
- **Root Solution:** BakaSU + SUSFS
- **Defconfig:** atoll_defconfig

## 📦 Cara Instalasi

1. Download file ZIP dari [Releases](../../releases)
2. Boot ke recovery (TWRP/OrangeFox)
3. Flash ZIP kernel
4. Reboot system
5. Install [BakaSU Manager APK](https://github.com/Baka-SU/BakaSU/releases)

## 🛠️ Build Manual

### Prerequisites
- Linux environment (Ubuntu 20.04+ recommended)
- Minimum 16GB RAM
- 100GB+ free storage
- Git dan build tools

### Build Steps

```bash
# Clone repository
git clone --depth=1 -b Neko-Baka https://github.com/harapanhartono6-ops/Neko-Kernel.git
cd Neko-Kernel

# Setup BakaSU dan SUSFS
./setup_bakasu_susfs.sh

# Download Neutron Clang 24
mkdir -p ~/toolchains
cd ~/toolchains
wget https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/latest/download/neutron-clang-24-aarch64-linux-gnu.tar.zst
tar -I zstd -xf neutron-clang-24-aarch64-linux-gnu.tar.zst
mv neutron-clang neutron-clang-24

# Setup environment
export PATH=~/toolchains/neutron-clang-24/bin:$PATH
export ARCH=arm64

# Build kernel
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 vendor/atoll_defconfig
make -j$(nproc) O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 \
  CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
  CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu-
```

## 🔄 GitHub Actions Build

Kernel akan otomatis di-build ketika ada push ke branch `Neko-Baka`. Hasil build bisa didownload dari:
- **Artifacts** - Setiap commit
- **Releases** - Build final dengan tag

## 📋 Konfigurasi BakaSU+SUSFS

Konfigurasi berikut sudah aktif di kernel:

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

## 🔍 Testing

Setelah instalasi, test dengan:

```bash
# Cek BakaSU aktif
su -c "bakasu -v"

# Cek SUSFS
ksu_susfs
```

## 📱 Device Support

- Realme 6 Pro (RMX2061)
- Realme 6 Pro India (RMX2063)

## ⚠️ Disclaimer

- Backup data sebelum flash
- Kernel ini unofficial dan experimental
- Penulis tidak bertanggung jawab atas kerusakan device

## 🙏 Credits

- [BakaSU](https://github.com/Baka-SU/BakaSU) - Root solution
- [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) - Root hiding
- [Neutron Clang](https://github.com/Neutron-Toolchains) - Compiler
- [KernelSU](https://github.com/tiann/KernelSU) - Original KernelSU
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3) - Flasher

## 📄 License

GPL-2.0 (Kernel) / GPL-3.0 (Other components)

## 💬 Support

- [Telegram Group](https://t.me/BakaSU_Grp) - BakaSU support
- [Issues](../../issues) - Bug reports
