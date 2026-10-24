# 0087 GUI: early boot selesai, penyebab logo berhenti belum terbukti

**Update layout 2026-10-24:** root sekarang berada pada GPT `ios` menurut user;
ikuti [langkah/profil baru](IOS_PARTITION_NEXT.md). Audit geometry dan image
userdata pada dokumen ini bersifat historis.

2026-10-23. Sumber user: [jt9UtCcm](https://pixeldrain.com/u/jt9UtCcm),
`LGV60_XNU_trial_0087_GUI_bootlog_transkripsi.txt`, 12089 byte, SHA-256
`2df3afe6389e086e3fffbbf609b40fe1f7a0e333bdfab46151a83ba065b87af7`.
[Salinan asli](evidence/0087-full-user-transcription.txt),
[temuan terstruktur](evidence/0087-full-log-findings.json).

File adalah transkripsi manual foto 1000313009..1000313017 dengan baris terpotong,
overlap/duplikasi dan jeda antarfoto. Dimulai saat mount task sudah berjalan;
**bukan dump seluruh boot**. Trial terbaca `0087-gui-r39984162472`, console flag 1.
Foto terakhir dideskripsikan logo putih/ungu di latar hitam dan garis merah bawah.

**Update recovery:** audit live sudah memastikan volume HFSX 16 GiB pada userdata
32 GiB dan membackup tail log di luar volume. **Varian 0087-GUI-log sudah diuji dan
ring berhasil diambil**: [analisis paling baru](0087_PERSISTENT_LOG_ANALYSIS.md).
Marker service, exec SpringBoard/backboardd dan swap sudah tercapture; yang belum
jelas adalah liveness sesudah flush 5/heartbeat 13. Kernel dan payload selain
command line identik. [Audit dan prosedur capture](0087_RECOVERY_LOG_TRIAL.md).

## Kesimpulan dan prioritas

Root HFS sudah ter-mount dan userspace melanjutkan boot sesudah pesan filesystem,
SEP, cleanup dan random. Batas observasi saat ini adalah sesudah launchd menerima
cache dan logo menutupi console. Tidak ada bukti bahwa root mount gagal, bahwa
data volume terpisah wajib tersedia pada konfigurasi ini, atau bahwa pesan Nexus
yang dilaporkan terpisah menghentikan UI.

Prioritas utama: **observasi setelah cache/present pertama**, meliputi heartbeat,
exec/crash daemon dan surface/frame. Masalah kompatibilitas atribut HFS yang
menjelaskan kemungkinan error `/tmp` perlu diperiksa terarah secara terpisah.
Penyebab tunggal logo berhenti belum dapat ditentukan dari transkripsi ini.

## Urutan yang benar-benar terlihat

| Tahap | Bukti | Batas kesimpulan |
|---|---|---|
| Mount | `/dev/ufsroot0 on / (hfs, local, journaled, noatime)` | Root sudah digunakan; bukan loop gagal mount seperti trial RO lama |
| Data volume | `data volume missing, but not required in env: 0` | Konfigurasi mount sendiri mengatakan volume itu tidak wajib; tidak berarti semua path data sehat |
| SEP | `No SEP present on this device` lalu boot berlanjut | Sesuai implementasi tanpa SEP; bukan laporan kernel panic |
| UMD | Session UID 501, `diskSaveUserSessions Success`, persona dialokasikan, `DONE EARLYBOOT SETUP` | UMD melaporkan selesai; kegagalan foreground/notify yang ikut tercetak tidak membuktikan semua semantik sesi benar |
| Cleanup | `dc_reset: /tmp: Invalid argument`, sama untuk `/var/run` | Error nyata EINVAL, bukan bukti direktori tidak ada; boot menjalankan task berikutnya |
| Random | Sysctl `kern.prng.user_reseed_count` ENOENT; virtual random `(-147) (-536870212)` | Mismatch interface/helper tertentu; lihat audit binary di bawah |
| Launchd | `Using unsecure cache`, `Cache sent to launchd successfully`, dua `exec xpcproxy` | Cache diterima PID 1; belum membuktikan daemon berikutnya sukses initialization |
| Liveness | Heartbeat 3 → 5 → 6, SGI1 = 1 | Hidup sampai fase cache loader. Timer count terpotong; tidak ada heartbeat sesudah logo |

Marker publikasi IOAcceleratorES, record `SWEET FB: swap`, exec backboardd atau
SpringBoard, serta CRASH/panic tidak tercapture di file ini. Sebagian marker
startup memang dapat berada sebelum foto pertama. Ketidakhadiran di transkripsi
tidak membuktikan service/proses tersebut tidak pernah ada. `rapportd(82):
nxprov_create: 1` berasal dari laporan user sebelumnya, tidak ada dalam file ini;
jangan menyisipkannya sebagai baris lanjutan yang sudah diverifikasi.

## GetMasterBlock dan data volume

Error 16 adalah **EBUSY**, bukan ENODEV/EIO. Source Apple HFS
`$HOME/work/scratch/hfs/mount_hfs/mount_hfs.c:255` menunjukkan GetMasterBlock mencoba
membuka device untuk membaca metadata; caller metadata seperti
`getVolumeCreateDate()` dan `get_encoding_pref()` memiliki fallback bila pembacaan
itu gagal. Pada file baru, baris mounted-root dan boot task berikutnya memberi
bukti langsung bahwa pesan tersebut tidak menghentikan seluruh mount sequence.
Alasan spesifik EBUSY belum dilacak saat runtime; device root yang sedang mounted
adalah penjelasan yang konsisten, bukan bukti kerusakan media.

BindFS mendapat ENOENT=2 untuk preboot firmware/Pearl/factorydata yang tidak ada.
Task tetap berlanjut. Layout root port ini adalah HFS gabungan, bukan layout APFS
System/Data iPhone utuh. Jangan mengonversi volume, membuat partisi Data, mematikan
journal, atau reflash userdata hanya untuk menghilangkan pesan tersebut.

## Virtual random: asal kode error sudah diidentifikasi

Binary **`/usr/libexec/prng_seedctl` dari image host 20H392** diekstrak read-only
dan didisassemble. [Hash/input audit](evidence/0087-host-root-audit.json),
[excerpt disassembly](evidence/0087-earlyboot-disassembly.txt).

Pada VA `0x10000387c`, helper memanggil `IOServiceMatching("AppleVirtIOEntropy")`,
lalu `IOServiceGetMatchingService()`. Bila service tidak ada, branch
`0x1000038e0` mengisi status internal `-147` dan kode `0xe00002bc`
(`kIOReturnError`, signed `-536870212`), lalu mencetak persis pesan di foto.
Ini bukan bukti driver RAM, `/dev/random`, atau seluruh generator random kernel
gagal. Service entropy virtual itu tidak disediakan port timelm saat ini.

`kern.prng.user_reseed_count` adalah interface sysctl lain yang tidak ditemukan.
Port memakai built-in HMAC-SHA256 DRBG melalui patch 0014; helper Apple tidak
menemukan seluruh interface implementasi PRNG yang diharapkannya. Boot tetap
menjalankan cache loader sesudah error. Audit sumber entropy/reseed tetap pekerjaan
tersendiri; jangan mengiklankan seed sintetis sebagai entropy hardware atau
membuat dummy AppleVirtIOEntropy hanya untuk membungkam pesan.

## /tmp: kandidat mismatch atribut, bukan langsung masalah mode direktori

Disassembly `dirs_cleaner` menunjukkan jalur error `dc_reset: %s: %s` dapat dicapai
setelah `realpath()` atau `getattrlist()`. Getattrlist di VA `0x100002d40` meminta
common mask **`0x40038008`**: object type, owner, group, access mode dan
**`ATTR_CMN_DATA_PROTECT_FLAGS`**. Ini mempersempit pemeriksaan dibanding menebak
permission/path dari EINVAL.

Source HFS built-in: `bsd/sweet_hfs/sweet_hfs_compat.h` membersihkan konfigurasi
kernel dan memakai feature config HFS. `hfs_vnops.c:1152` menyediakan
`va_dataprotect_class` hanya pada build CONFIG_PROTECT. Di VFS,
`vfs_attrlist.c:2767..2793` menolak atribut yang tetap unsupported dengan EINVAL
bila caller tidak meminta returned-attributes mask. Ini kandidat source yang kuat
untuk incompatibility query data protection pada HFS tanpa content protection.
**Belum ada runtime trace yang memastikan apakah realpath atau getattrlist yang
gagal pada HP, atau bit atribut mana penyebabnya.**

Probe yang membedakan: pada path live yang sama, bandingkan getattrlist mask
`0x40038008` dengan `0x00038008`, serta stat/open/create/unlink file temporer.
Jika hanya query dengan bit data protection gagal, audit dukungan read attribute
untuk volume tanpa protection, dengan semantik jujur. Jangan mengembalikan success
pada operasi protection yang tidak diimplementasikan.

Audit read-only **image host asli**, bukan filesystem HP yang sudah mengalami RW
boot, menunjukkan `/tmp -> private/var/tmp`, target root:root `01777`, dan
`/private/var/run` root:daemon `0775`. Preferensi migrasi sudah mempunyai
`LastSystemVersion=20H392`, `SyntheticDidUpgrade=false`; preferensi SpringBoard
memiliki BKNoWatchdogs dan SetupDone sudah disetel. Jadi mengulang tweak/reflash
image host tidak menyasar ketidaksesuaian baru yang terbukti.

**Update recovery: metadata dan preferensi yang sama kemudian diverifikasi pada
filesystem HP secara read-only melalui B-tree**, termasuk `/tmp` 01777, `/var/run`,
migrasi 20H392/SyntheticDidUpgrade=false, BKNoWatchdogs dan SetupDone. Lihat
[audit live](evidence/0087-live-hfs-path-audit.json). Ini memperkuat alasan untuk
menguji kontrak atribut sebelum mengubah permission/path; belum menggantikan
probe syscall iOS atau pemeriksaan konsistensi seluruh volume.

## Logo, console dan tanggal

Profil ini memiliki `sweetfb_noconsole=1`. `AppleCLCD::present()` menyetel mute
sebelum validasi/copy layer; `_cnputs()` tetap mengisi ring log RAM sebelum
melewati gambar console. Dengan demikian berhentinya teks saat logo tampil
konsisten dengan perilaku profil. Tidak membuktikan copy/present berhasil penuh
atau kernel hang. Profil aktif `sweetlog=0` tidak mem-flush ring tersebut ke disk;
jangan menganggap tail log dari trial lama sebagai log 0087 ini.

Tanggal launchd `1969-12-31 16:00:xx` dan timestamp sesi `1970-01-01 00:00:xx`
konsisten dengan jam dekat Unix epoch dan perbedaan zona waktu. Ini sesuai
fallback kalender tanpa RTC valid, bukan tanggal firmware. Belum ada kaitan yang
terbukti dengan layar logo; audit clock setelah observasi boot utama tersedia.

## Roadmap saat transkripsi (capture langkah 1 sekarang selesai)

1. **Tes 0087-GUI-log, lalu pull log sesudah cache.** Audit geometry, backup tail
   dan repack sudah selesai tanpa kernel build baru; ikuti
   [instruksi trial recovery](0087_RECOVERY_LOG_TRIAL.md). Dasar validasinya:
   `HFS_end = blockSize * totalBlocks` dari volume header offset 1024, signature
   valid, dan area terakhir `(4 MiB + 4 KiB)` seluruhnya di luar volume HFS serta
   di dalam partisi. Ulangi audit bila geometry berubah. Image mengaktifkan
   `sweetlog=1 ufslogsecs=10` dan trial unik dengan baseline lain tetap sama.
   Decode ring memakai `tools/sweet-log.py`, cocokkan trial ID dan flush sequence;
   command ADB dengan forward port ada pada instruksi trial.
2. Bila akses/persistensi itu belum tersedia, **0088 hanya instrumentasi diag**:
   status heartbeat/timer dan present/copy counters yang tetap terbaca setelah
   frame menimpa console, dengan output bounded. Bedakan present diterima, layer
   ditolak, copy selesai, serta daemon exec/crash. Hindari sampler lama yang
   memegang task_lock saat membaca user VM dan jangan mengaktifkan hardware USB
   SWEET yang belum diport. Status framebuffer sendiri tidak cukup membuktikan
   kernel hang bila workloop display berhenti.
3. Probe `/tmp`/`/var/run` dan atribut di atas secara terpisah. Perbaiki hanya
   kontrak yang dibuktikan, tanpa perubahan layout root atau fake protection.
4. Dari log baru: bila daemon hidup tetapi tidak ada swap, telusuri IPC/renderer,
   IOSurface/IOMFB dan migrasi. Bila copy berjalan tetapi gambar salah, audit
   format/stride/crop/lifetime. Bila heartbeat benar-benar berhenti, telusuri
   lock/UFS/scheduler. GPU Adreno 650 dan direct DPU scanout tetap tahap kemudian.

Pertahankan `cpus=1`, timer 27, SGI1 fix, `timelm_wdt=stop`, UFS-RW, dan fallback
0087/0086. Satu perubahan utama per trial, manifest/hash unik, upload boot.img
dengan `pd upload`. Kernel build CI hanya bila source berubah; shim Linux boleh
`JOBS=56`. Kernel tidak diubah pada audit ini; repack logging dijelaskan pada
dokumen recovery di atas. Akses ADB hanya membaca partisi, tidak mengubah filesystem HP.
