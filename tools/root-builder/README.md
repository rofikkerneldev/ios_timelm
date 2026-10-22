# ios16-root-builder — image root iOS 16 untuk LG V60 ThinQ 5G (timelm)

Paket mandiri untuk membuat **image root iOS 16.7.16 (20H392, iPhone X)** dan
**.simg**-nya (untuk `fastboot flash userdata`) di Linux server mana pun.

Isi paket:

| file | fungsi |
|---|---|
| `build-iosroot.sh` | entry point: unduh member IPSW -> buat volume HFS+ -> tweaks -> fsck -> `img2simg` |
| `mkiosroot.sh` | membangun volume HFS+ 16 GiB (case-sensitive, journaled) dari dmg APFS |
| `sweet-root-tweaks.py` | perubahan bring-up: launchd.plist, containers, keybag, Setup di-skip, audio, dll |
| `remotezip.py` | menarik member IPSW dari Apple's CDN dengan HTTP range request |
| `bin/apfs-fuse` | membaca APFS (LZBITMAP) tanpa root |
| `bin/mkfs.hfsplus`, `bin/fsck.hfsplus` | buat/periksa volume HFS+ |
| `bin/img2simg` | image sparse untuk fastboot |
| `src/` | source tool (untuk rebuild kalau binary tidak jalan di server kamu) |

Yang perlu dari server kamu: **root** (untuk mount HFS+) dan `rsync`.

## Cara pakai

```bash
tar xf ios16-root-builder.tar.zst          # zstd: zstd -d < file.tar.zst | tar x
cd ios16-root-builder
sudo apt install rsync                     # satu-satunya dependency dari apt
sudo ./build-iosroot.sh
```

Lama: sekitar **40-90 menit** (unduh 7.5 GB member IPSW + rsync ~12 GB + img2simg).
Butuh disk ± 30 GB (work dir `$HOME/ios16-root-work`, bisa diubah: `WORK=/path sudo -E ./build-iosroot.sh`).

Keluarannya:

```
$HOME/ios16-root-work/out/ios16-root-20H392.img    (16 GiB, HFS+ journaled)
$HOME/ios16-root-work/out/ios16-root-20H392.simg   (~12 GB, sparse)
```

Lalu di HP (fastboot):

```bash
fastboot -S 512M flash userdata ios16-root-20H392.simg
fastboot boot shim-boot-timelm-high-ufs.img
```

`shim-boot-timelm-high-ufs.img` = kernel + ADT timelm dengan cmdline
`rd=ufsroot0 ufsrw=1 rootrw=1` (root dari UFS, read-write).

## Catatan

- Root filesystem-nya **device-independent**: userland iPhone X (D22AP).
  Yang khas LG V60 hanya ADT, boot image, dan cmdline.
- Volume HFS+-nya 16 GiB, isinya ±12 GB (OS rootfs + cryptex SystemOS/AppOS
  + shared cache dyld + keybag sistem) -> `.simg` ±12 GB.
- Member IPSW diambil langsung dari Apple's CDN; kalau sudah ada di
  `$WORK/ipsw-x` (nama file sama) tidak diunduh ulang.
- Kalau `bin/` tidak jalan (versi glibc berbeda), build ulang tanpa root:
  `cd src && ./build-root-tools.sh` (butuh gcc, make, python3-pip, network).
- Setelah flashing, kernel menulis ke userdata; image asli tetap ada di
  `$WORK/out` sebagai restore.
