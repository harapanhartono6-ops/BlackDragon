# Neko-Kernel for realme 6 Pro (RMX2061)

Kernel dengan integrasi **BakaSU + SUSFS** untuk alternatif root, dikompilasi menggunakan **Neutron Clang 24**.

## Struktur Tree

```
Neko-Kernel/
├── arch/arm64/boot/dts/mediatek/
│   ├── mt6785.dtsi          # Device Tree Source for MT6785 (Helio G90T)
│   ├── rmx2061.dts          # Board DTS for realme 6 Pro (RMX2061)
│   └── Makefile             # Updated to include rmx2061.dtb
├── arch/arm64/configs/
│   └── rmx2061_defconfig    # Device-specific defconfig with BakaSU support
├── fs/stat.c                # Manual hooks for BakaSU (stat, newfstatat, fstat64, fstatat64)
├── fs/exec.c                # Manual hooks for BakaSU (execveat, post_execveat)
├── fs/open.c                # Manual hooks for BakaSU (faccessat)
├── kernel/reboot.c          # Manual hooks for BakaSU (sys_reboot)
├── drivers/kernelsu -> ../KernelSU/kernel/  # BakaSU symlink
├── KernelSU/                # BakaSU source code
├── build.sh                 # Build script with Neutron Clang 24
├── AnyKernel3/
│   └── anykernel.sh         # Flashing script for RMX2061
└── setup_bakasu.sh          # BakaSU setup script
```

## Apa yang Ditambahkan (perbandingan dengan tree asli)

| Komponen | Status | Keterangan |
|----------|--------|------------|
| Device Tree (MT6785) | ✅ Ditambahkan | `mt6785.dtsi` + `rmx2061.dts` |
| Device Defconfig | ✅ Ditambahkan | `rmx2061_defconfig` dengan CONFIG_KSU |
| BakaSU Integrasi | ✅ Ditambahkan | Via setup script + manual hooks |
| Manual Hooks | ✅ Diterapkan | stat.c, exec.c, open.c, reboot.c |
| Neutron Clang 24 | ✅ Dikonfigurasi | Di build.sh |
| SUSFS | ⚠️ Perlu backport | Kernel 4.14 Non-GKI, perlu backport dari gki-android12-5.10 |
| AnyKernel3 | ✅ Siap | `anykernel.sh` untuk RMX2061 |

## Cara Build

```bash
# Masuk ke direktori kernel
cd Neko-Kernel

# Jalankan build script
chmod +x build.sh
./build.sh
```

Build script akan:
1. Download Neutron Clang 24 dari GitHub releases
2. Clone GCC toolchain dan AnyKernel3 jika belum ada
3. Build kernel dengan `rmx2061_defconfig`
4. Buat flashable zip di `~/AnyKernel3/`

## Persyaratan

- `curl` untuk download toolchain
- `zstd` untuk extract Neutron Clang
- `git` untuk clone toolchain dan AnyKernel3
- Minimal 4GB RAM untuk kompilasi

## Catatan SUSFS

SUSFS tidak didukung natively untuk kernel Non-GKI 4.14. Untuk mengaktifkan SUSFS:
1. Clone SUSFS repo: https://gitlab.com/simonpunk/susfs4ksu
2. Checkout branch `gki-android12-5.10`
3. Apply kernel-side patches secara manual
4. Enable `CONFIG_KSU_SUSFS=y` di `rmx2061_defconfig`

## Kontribusi

Kernel ini dikembangkan untuk realme 6 Pro (RMX2061) dengan MediaTek MT6785 (Helio G90T).
