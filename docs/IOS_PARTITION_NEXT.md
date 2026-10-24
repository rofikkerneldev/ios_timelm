# Langkah berikutnya: root pada GPT ios, lalu diagnostik 0088

**Checkpoint terbaru 2026-10-24:** trial 0087-ios sudah dites **10 menit dengan
stopwatch**, snapshot berakhir HB=8/flush=6. Kernel diagnostik 0088 sudah diuji:
footer HB=71/copy=6 kemudian dilaporkan diam; pull header HB=62/flush=6.
**Ikuti [hasil 0088 dan trial no-idle](0088_PHONE_RESULT_AND_NOIDLE.md)**
untuk image pembanding terbaru, pembacaan footer sebelum recovery dan roadmap.
Instruksi 0087 di bawah dipertahankan sebagai baseline/audit layout.

2026-10-24. User memindahkan filesystem iOS ke partisi GPT bernama **`ios`** dari
hasil pembagian area userdata; partisi Android userdata, Windows ESP dan win juga
ada pada layout baru. **Update:** user menyambungkan kembali ADB recovery dan
mem-flash image/sparse image iOS16 ke `ios`. Audit live read-only berhasil;
tidak ada mount, fsck, perubahan GPT atau write filesystem melalui ADB.

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
untuk memilih nama GPT baru. **Live terverifikasi:** GPT entry 31, `/dev/block/sda31`,
LUN 0, sektor 4096. Header dan tabel entry GPT lolos CRC; extent partisi cocok
dengan ukuran/offset yang dilaporkan sysfs/blockdev.

**Image baseline 0087, sudah diuji HP sepuluh menit; lihat checkpoint di atas:**
[timelm-0087-ios-rw-c1-wdtstop-gui-log.img](https://pixeldrain.com/u/wwiAWeh7).

```text
trial  0087-ios-gui-log-r39984162472
SHA256 9de708639b713235ccf722ef91ef37510e327f9589847022bbdc2fa95ca3bd46
kernel 42b9033b867b5b02ff8eb2beab03a983a781f6a3c6f129c4380c9132332823c0
```

```bash
fastboot boot timelm-0087-ios-rw-c1-wdtstop-gui-log.img
```

Ini repack kernel 0087, dengan `ufsroot=ios`, GUI console mute dan **`sweetlog=1`**
sesudah audit dan backup area log baru. Logger flush setiap 10 detik.
Kernel, shim, ADT, DTB, static init dan seluruh payload selain command-line buffer
identik dengan 0087-GUI-log sebelumnya. Watchdog-stop, cpus=1, timer/SGI fix dan
konfigurasi grafis tetap sama. Ini menyesuaikan target storage; penyebab GUI diam
belum diperbaiki. Boot RW mengizinkan write filesystem hanya pada partisi `ios`
yang dipilih driver; raw-tail writer memakai area terverifikasi di partisi yang
sama, di luar extent HFSX.

[Manifest dan verifikasi](evidence/0087-ios-gui-log-build.json). Payload/10 segmen,
kesetaraan komponen, pemilihan partisi, dan hash upload Pixeldrain telah dicek.
Alternatif console tanpa persistent writes:
[0087-ios-diag](https://pixeldrain.com/u/6jWRQptn),
[manifest](evidence/0087-ios-diag-build.json), `sweetlog=0`.

Cari log:

```text
SWEET UFS: looking for partition "ios"
SWEET UFS: "ios" on LUN 0: first block ..., ... MiB, read-write, DMA ...
BSD root: ufsroot0, ...
```

Jika `no GPT partition named "ios"` muncul, verifikasi label dan LUN sebelum
mengubah driver. Tidak ada fallback otomatis ke userdata ketika pencarian gagal.
Jika journal/mount gagal, kumpulkan error aktual; jangan reflash partition lain.

## 2. Audit partisi baru sudah selesai

[Geometry live dan backup](evidence/ios-live-recovery-20261024.json),
[audit file live](evidence/ios-live-hfs-files-20261024.json).

| Parameter | Nilai |
|---|---|
| GPT `ios` / block device | Entry 31, `/dev/block/sda31`, LUN 0 |
| Ukuran partisi | 20705009664 byte, sekitar 19,28 GiB |
| Logical sector | 4096 byte |
| HFSX (`HX`) | 4096 × 4194304 blocks = 17179869184 byte / 16 GiB |
| Tail log relatif partisi | 20700811264 byte, block 5053909, panjang 4198400 byte |
| Gap antara akhir HFSX dan awal log | 3520942080 byte |

Header 8 KiB pertama persis cocok dengan image host asli. Ini memverifikasi header,
bukan checksum seluruh 16 GiB. File live yang dibaca melalui B-tree memastikan
`/tmp -> private/var/tmp` dengan target 01777, `/var/run` root:daemon 0775,
migrasi 20H392/SyntheticDidUpgrade=false, BKNoWatchdogs dan SetupDone sesuai image
yang disiapkan. Recovery tidak menyediakan driver HFS untuk mount, sehingga audit
menggunakan pembacaan blok dan metadata read-only.

Seluruh area tail baru dibackup sebelum mengaktifkan logging pada image:

```text
/home/rofikkernel/work/timelm-ios-recovery-20261024/ios-tail-before-logging.bin
SHA256 c8dc48deebf8732024c54b41721dd43e3328d78f14d3d603468dfbff92676e6e
```

Magic lama nol, bukan SWEETLOG. Geometry di atas berlaku untuk layout sekarang;
audit ulang bila partisi atau volume diresize.

**Jangan boot image lama `GnxdmsDC` pada layout baru.** Image itu tidak mempunyai
`ufsroot=ios`, sehingga masih memilih userdata, dan mengaktifkan tail logging.
Audit 32-GiB userdata/16-GiB HFSX sebelumnya adalah bukti layout historis; tidak
mengizinkan write pada userdata Android sekarang ataupun tail partisi `ios` baru.

Contoh pembacaan read-only untuk audit ulang bila layout berubah:

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

Setelah boot image GUI-log di atas, tunggu **tiga menit setelah logo dengan
stopwatch**, atau catat bila ada perubahan/reboot lebih awal, lalu kembali ke
recovery dan sambungkan forward ADB lagi. Agent mengambil ring menggunakan
perintah di atas. Pastikan ukuran dump 4198400, header/flush sequence valid dan
trial **`0087-ios-gui-log-r39984162472`** ditemukan. Jangan menganggap ring lama
hasil tes baru. Ring ini merekam console kernel/daemon yang memang diarahkan ke
console; bukan seluruh unified log iOS.

Jika memakai alternatif ios-diag `6jWRQptn`, persistent logging tetap mati dan
tidak menghasilkan tail trial baru. Profil GUI-log ini masih memakai logger 0087;
gap observasi pada snapshot terakhir tetap perlu dinilai, bukan dianggap selesai.

### Alternatif carrier yang diusulkan user

[Audit read-only carrier](evidence/carrier-readonly-audit-20261024.json):
`/dev/block/sda18`, 50331648 byte (48 MiB), filesystem ext4 berlabel `carrier`.
Superblock menyatakan 12288 blocks × 4096 byte, persis seluruh ukuran partisi.
Ada 8595 blocks bebas di dalam filesystem, bukan area di luar filesystem.

Logger SWEET sekarang menulis raw blocks pada partisi root yang dipilih. Tidak
ada parameter terpisah untuk memilih `carrier`; mengganti `ufsroot=carrier`
malah memilih root yang salah. Menulis log raw pada tail carrier dapat menimpa
data/metadata filesystem. Log file normal yang dialokasikan filesystem atau
partisi khusus log memerlukan rancangan terpisah; jangan format/mengubah carrier
untuk pekerjaan ini. Audit hanya membaca metadata/8 KiB, tidak mount atau write.

Untuk trial ini tetap gunakan tail **ios di luar HFSX** yang sudah dibuktikan dan
dibackup. Carrier dan ios juga memakai UFS/LUN/controller yang sama, sehingga
pemindahan alamat log tidak menghilangkan ketergantungan pada driver/mutex UFS.
Observer independen pada roadmap 0088 tetap diperlukan bila logging berhenti.

## 3. Source diagnostik 0088 sudah dibuild

Boot XNU dari root `ios` sudah terkonfirmasi. Observer heartbeat, copy-completed,
fase/errno logger-UFS dan footer framebuffer telah diimplementasikan. Patch 0088
dan targeted checks lolos, CI kernel sukses, shim dibuild `JOBS=56`, manifest/trial
unik serta upload Pixeldrain selesai. [Trial 0088](0088_DIAGNOSTIC_TRIAL.md)
menjelaskan batas observer dan langkah selanjutnya. Belum ada hasil HP 0088.
Jangan gabungkan SMP/GPU atau perubahan filesystem spekulatif.

Packaging script sekarang memakai `UFS_PARTITION=ios` default, menyisipkan
`ufsroot=ios` juga pada custom CMDLINE yang belum memilikinya, serta menolak
argumen partisi konflik/duplikat. Kernel masih mempunyai default historis userdata;
gunakan script/profil baru, jangan sekadar menyalin command line lama.
[Checks packaging dan mock ADB](evidence/ios-partition-packaging-checks.json).
