# Langkah berikutnya: root pada GPT ios, lalu diagnostik 0088

2026-10-24. User memindahkan filesystem iOS ke partisi GPT bernama **`ios`** dari
hasil pembagian area userdata; partisi Android userdata, Windows ESP dan win juga
ada pada layout baru. ADB saat ini sengaja tidak disambungkan. Tidak ada akses ADB,
mount, perubahan GPT atau filesystem phone pada pekerjaan packaging ini.

User juga mengoreksi durasi tes sebelumnya: mungkin sekitar **tiga menit**, bukan
pengukuran lima menit. Kesimpulan tetap: snapshot flush 5/heartbeat 13 belum dapat
membedakan kernel berhenti dari jalur console/logger/UFS yang berhenti.

## 1. Pakai profil dengan pemilihan partisi yang benar

Source kernel 0087 `bsd/dev/sweet_ufs.c`, `sweet_ufs_init()` membaca boot-arg
**`ufsroot`** sebagai nama GPT, default bawaan kernel masih `userdata`, dan
mencarinya pada **LUN 0**. Device BSD yang diekspos tetap `ufsroot0`, jadi argumen
yang dibutuhkan adalah:

```text
rd=ufsroot0 ufsroot=ios ufsrw=1 rootrw=1
```

Jangan mengganti root device menjadi `rd=ios`. Kernel tidak membutuhkan rebuild
untuk memilih nama GPT baru. User mengonfirmasi GPT; tujuan symlink/geometry/LUN
partisi baru belum diperiksa live. Pembagian userdata lama konsisten dengan LUN0,
tetapi verifikasi alamat yang sebenarnya saat recovery tersedia.

**Image siap tes, belum diuji HP:**
[timelm-0087-ios-rw-c1-wdtstop-diag.img](https://pixeldrain.com/u/6jWRQptn).

```text
trial  0087-ios-diag-r39984162472
SHA256 39be255935f891cf1c62280843993d23f2b920ca89aba2c0dd06bacb3581c306
kernel 42b9033b867b5b02ff8eb2beab03a983a781f6a3c6f129c4380c9132332823c0
```

```bash
fastboot boot timelm-0087-ios-rw-c1-wdtstop-diag.img
```

Ini repack kernel 0087, dengan `ufsroot=ios`, console diagnostik dan **`sweetlog=0`**.
Kernel, shim, ADT, DTB, static init dan seluruh payload selain command-line buffer
identik dengan 0087-diag sebelumnya. Watchdog-stop, cpus=1, timer/SGI fix dan
konfigurasi grafis tetap sama. Ini menyesuaikan target storage; penyebab GUI diam
belum diperbaiki. Boot RW mengizinkan write filesystem hanya pada partisi `ios`
yang dipilih driver; persistent raw-tail writer dimatikan.

[Manifest dan verifikasi](evidence/0087-ios-diag-build.json). Payload/10 segmen,
kesetaraan komponen, pemilihan partisi, dan hash upload Pixeldrain telah dicek.

Cari log:

```text
SWEET UFS: looking for partition "ios"
SWEET UFS: "ios" on LUN 0: first block ..., ... MiB, read-write, DMA ...
BSD root: ufsroot0, ...
```

Jika `no GPT partition named "ios"` muncul, verifikasi label dan LUN sebelum
mengubah driver. Tidak ada fallback otomatis ke userdata ketika pencarian gagal.
Jika journal/mount gagal, kumpulkan error aktual; jangan reflash partition lain.

## 2. Audit partisi baru saat ADB disambungkan kembali

**Jangan boot image lama `GnxdmsDC` pada layout baru.** Image itu tidak mempunyai
`ufsroot=ios`, sehingga masih memilih userdata, dan mengaktifkan tail logging.
Audit 32-GiB userdata/16-GiB HFSX sebelumnya adalah bukti layout historis; tidak
mengizinkan write pada userdata Android sekarang ataupun tail partisi `ios` baru.

Saat user menyambungkan recovery/forward kembali, baca read-only:

```bash
SWEET_ADB_BIN=/home/rofikkernel/alpha/out/host/linux-x86/bin/adb
"$SWEET_ADB_BIN" -H 127.0.0.1 -P 15037 shell \
  'readlink -f /dev/block/by-name/ios; blockdev --getsize64 /dev/block/by-name/ios; blockdev --getss /dev/block/by-name/ios'
# Simpan header ini ke file host, lalu parse signature/blockSize/totalBlocks.
"$SWEET_ADB_BIN" -H 127.0.0.1 -P 15037 exec-out \
  'dd if=/dev/block/by-name/ios bs=4096 count=2 2>/dev/null' \
  > "$HOME/work/ios-partition-first8k.bin"
```

Verifikasi GPT/LUN dan bahwa filesystem dimulai pada offset 0 partisi yang benar.
Hitung extent HFSX dari header; **jika volume memenuhi partisi, tail logger lama
tidak boleh diaktifkan** karena akan menulis ke dalam filesystem. Jika ada ruang
di luar volume, audit bounds dan backup area itu dahulu. Jangan menggunakan
offset block 8387583 atau `/dev/block/sda28` dari audit lama sebagai konstanta baru.
Jangan membuat/menggeser partisi ESP/win/userdata untuk logging tanpa tugas baru.

`tools/sweet-log-pull.sh` sekarang memilih `ios` secara default dan mendukung
forward ADB melalui environment berikut. Gunakan hanya setelah ada trial baru
yang memang mengaktifkan logging pada area yang sudah diverifikasi:

```bash
SWEET_LOG_PARTITION=ios \
SWEET_ADB_BIN=/home/rofikkernel/alpha/out/host/linux-x86/bin/adb \
SWEET_ADB_HOST=127.0.0.1 SWEET_ADB_PORT=15037 \
sh tools/sweet-log-pull.sh "$HOME/work/ios-console.txt"
```

Image ios-diag baru **tidak menyimpan ring ke disk**. Tidak ada alasan membaca
tail dan menganggapnya hasil tes baru sampai logging kembali diaktifkan dengan
geometry yang benar.

## 3. Baru lanjut source diagnostik 0088

Setelah root `ios` verified, implementasikan observer heartbeat, copy-completed,
fase/errno logger-UFS dan status framebuffer sesuai
[roadmap 0088](0087_PERSISTENT_LOG_ANALYSIS.md#roadmap-0088-untuk-opencode).
Status layar diperlukan bila partisi baru tidak punya area log yang aman.
Kompilasi/check patch terarah, build CI kernel, shim `JOBS=56`, manifest/trial unik,
lalu `pd upload`. Jangan gabungkan SMP/GPU atau perubahan filesystem spekulatif.

Packaging script sekarang memakai `UFS_PARTITION=ios` default, menyisipkan
`ufsroot=ios` juga pada custom CMDLINE yang belum memilikinya, serta menolak
argumen partisi konflik/duplikat. Kernel masih mempunyai default historis userdata;
gunakan script/profil baru, jangan sekadar menyalin command line lama.
[Checks packaging dan mock ADB](evidence/ios-partition-packaging-checks.json).
