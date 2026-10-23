# 0087-GUI-log: capture sesudah logo melalui ring persisten

2026-10-23. Kernel tetap 0087 dari CI 39984162472. **Image baru belum diuji HP.**
Ini trial logging, bukan klaim perbaikan penyebab logo berhenti.

Download: [timelm-0087-ufs-rw-c1-wdtstop-gui-log.img](https://pixeldrain.com/u/GnxdmsDC)

```text
SHA256 e1dfb191b5988c8985510db70f1b03bea30dad27b53b0819bc849a3f9fae8e59
trial  0087-gui-log-r39984162472
kernel 42b9033b867b5b02ff8eb2beab03a983a781f6a3c6f129c4380c9132332823c0
```

[Manifest dan perbandingan komponen](evidence/0087-gui-log-build.json).
Upload memakai `pd upload`; hash dan ukuran Pixeldrain cocok. Verifikasi 10 segmen,
ADT/DTB/timer dan kesetaraan payload di luar buffer command line lulus.

## Yang berubah

Kernel, shim, ADT termasuk random seed, DTB, static init dan seluruh payload
di luar command-line buffer **identik dengan image 0087-GUI sebelumnya**.
Command line mengubah `sweetlog=0` menjadi `sweetlog=1`, menambahkan
`ufslogsecs=10` secara eksplisit (sama dengan default) dan trial ID baru.
`cpus=1`, UFS-RW, `timelm_wdt=stop`, canvas, IOAcceleratorES compatibility service,
console mute, refresh 5 Hz dan bounded AKS logging dipertahankan.

Ring menangkap output console sebelum pengecekan mute, sehingga gambar/console
yang tertutup logo tetap memiliki jejak teks. Ini mencakup kernel console dan
output daemon yang memang diarahkan ke console, bukan seluruh unified logging
iOS. Snapshot disimpan tiap 10 detik; bagian paling akhir dapat hilang jika sistem
berhenti sebelum flush berikutnya.

## Audit recovery sudah dilakukan

User menyediakan forwarding ADB server pada `127.0.0.1:15037`. Binary lokal:
`/home/rofikkernel/alpha/out/host/linux-x86/bin/adb`. Recovery root berhasil
diakses; userdata tidak mounted. Tidak ada mount/fsck/write userdata melalui ADB.

| Parameter live | Nilai |
|---|---|
| Userdata | `/dev/block/sda28`, 34359738368 byte = 32 GiB |
| Logical sector | 4096 byte |
| Header volume | `HX` / HFSX, offset 1024 |
| Block volume | 4096 byte × 4194304 blocks = 17179869184 byte = 16 GiB |
| Awal area log relatif partisi | 34355539968 byte, block 8387583 |
| Panjang area log | 4198400 byte = 1025 blocks |
| Gap sesudah volume sebelum log | 17175670784 byte |

Area log dibuktikan di luar extent volume HFSX dan di dalam userdata pada layout
HP ini. Isi lama seluruh area telah dibackup sebelum membuat image logging:

```text
/home/rofikkernel/work/timelm-0087-full-log/userdata-tail-before-log.bin
SHA256 06955cde7f98b9503653b906e9634732d59a17a6dc2cb1a0e453fbdd4adaab86
```

Magic lama berisi nol, bukan `SWEETLOG`. [Hasil audit lengkap](evidence/0087-live-recovery-geometry.json).
Audit berlaku untuk layout tersebut; ulangi bila partisi/volume diresize.

Koneksi sempat terputus, kemudian tersedia kembali. Audit file live berhasil
melalui 17 read B-tree: `/tmp` menuju target root:root 01777, `/var/run` root:daemon
0775; preferensi migrasi 20H392/SyntheticDidUpgrade=false, BKNoWatchdogs=true dan
SetupDone/SetupFinishedAllSteps=true terkonfirmasi pada HP.
[Bukti live](evidence/0087-live-hfs-path-audit.json). Ini memeriksa metadata dan
preferensi tersimpan, bukan syscall getattrlist/create pada iOS atau fsck penuh.
Scratch auditor ada di `$HOME/work/timelm-0087-full-log/live_hfs_readonly.py`;
recovery tidak menyediakan driver HFS untuk mount langsung. Tidak ada mount atau
perubahan filesystem selama audit.

## Tes HP berikutnya dan pembacaan log

Di komputer yang terhubung fastboot ke HP:

```bash
fastboot boot timelm-0087-ufs-rw-c1-wdtstop-gui-log.img
```

Biarkan sekitar lima menit setelah logo muncul untuk merekam aktivitas berikutnya,
catat bila reboot terjadi lebih awal, lalu kembali ke recovery dan sambungkan
forward ADB yang sama. Tidak perlu flash boot partition atau userdata. Setelah
recovery tersedia, agent mengambil log dengan perintah server berikut:

```bash
SWEET_ADB_BIN=/home/rofikkernel/alpha/out/host/linux-x86/bin/adb
SWEET_LOG_DIR="$HOME/work/timelm-0087-gui-log-result"
mkdir -p "$SWEET_LOG_DIR"
"$SWEET_ADB_BIN" -H 127.0.0.1 -P 15037 devices -l
"$SWEET_ADB_BIN" -H 127.0.0.1 -P 15037 shell \
  'blockdev --getsize64 /dev/block/by-name/userdata; blockdev --getss /dev/block/by-name/userdata'
# Nilai geometry harus tetap sama dengan tabel sebelum memakai offset tetap ini.
"$SWEET_ADB_BIN" -H 127.0.0.1 -P 15037 exec-out \
  'dd if=/dev/block/by-name/userdata bs=4096 skip=8387583 count=1025 2>/dev/null' \
  > "$SWEET_LOG_DIR/tail.bin"
python3 tools/sweet-log.py "$SWEET_LOG_DIR/tail.bin" "$SWEET_LOG_DIR/console.txt"
```

Simpan file mentah beserta hash. Validasi ukuran 4198400, magic/version/ring size,
flush sequence > 0 dan **trial `0087-gui-log-r39984162472` dalam isinya**. Jangan
menarik kesimpulan dari ring lama atau file pull yang terpotong. Jika tidak ada
header, periksa apakah log thread mulai, root RW dan UFS flush berhasil; jangan
langsung menyatakan kernel mati. Jika hanya log awal yang tersimpan, bedakan
freeze seluruh sistem dari worker logging/UFS yang berhenti.

Fokus analisis: heartbeat sesudah cache/present, exec/crash backboardd/SpringBoard,
surface create/lookup dan 16 swap awal, IPC/entitlement atau migrasi yang menunggu,
serta error I/O nyata jika muncul. Selanjutnya pilih satu perubahan terarah dalam
[roadmap utama](0087_FULL_LOG_ANALYSIS.md) dan [roadmap display](TOPAZ_DISPLAY_COMPARISON.md).
