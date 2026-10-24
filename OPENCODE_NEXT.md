# Handoff OpenCode — LG V60 / timelm

Checkpoint terbaru 2026-10-24. Baca file ini dahulu; riwayat ada di `docs/evidence/`.

**Layout aktif: GPT `ios` sudah diaudit setelah user mem-flash iOS16 img/simg.**
ADB recovery tersambung kembali; pembacaan live read-only berhasil. `ios` adalah
GPT entry 31, `/dev/block/sda31`, **LUN 0**, sektor 4096. Partisi 20705009664 byte
(sekitar 19,28 GiB), HFSX di dalamnya 17179869184 byte (16 GiB). Header/entry GPT
lolos CRC dan cocok dengan sysfs/blockdev. [Geometry](docs/evidence/ios-live-recovery-20261024.json).

**Image tes utama: 0087-ios-GUI-log, belum diuji HP.**
[Download wwiAWeh7](https://pixeldrain.com/u/wwiAWeh7),
[manifest](docs/evidence/0087-ios-gui-log-build.json),
[langkah tes dan pull log](docs/IOS_PARTITION_NEXT.md).
Trial `0087-ios-gui-log-r39984162472`, SHA256
`9de708639b713235ccf722ef91ef37510e327f9589847022bbdc2fa95ca3bd46`.
Kernel/shim/ADT/DTB/static init dan payload selain command line identik 0087-GUI-log
historis; target sekarang **ufsroot=ios**, watchdog-stop tetap aktif, logger 10s.
Ini capture baseline setelah perpindahan/fresh flash, belum perbaikan source GUI.

**Area log baru di ios sudah diverifikasi dan dibackup:** tail relatif partisi
20700811264 byte (block 5053909), panjang 4198400 byte; gap sesudah HFSX sebelum
log 3520942080 byte. Backup `$HOME/work/timelm-ios-recovery-20261024/ios-tail-before-logging.bin`.
Audit ini hanya berlaku pada layout sekarang; ulangi jika partisi/volume diresize.
[File live](docs/evidence/ios-live-hfs-files-20261024.json): tmp/run metadata,
preferensi migrasi 20H392, BKNoWatchdogs dan SetupDone sesuai image yang disiapkan.
Audit tidak melakukan mount, fsck, perubahan GPT atau write filesystem phone.

User mengusulkan carrier untuk log. [Audit carrier](docs/evidence/carrier-readonly-audit-20261024.json)
menemukan `/dev/block/sda18`, 48 MiB, ext4 yang mencakup seluruh partisi. Jangan
raw-write carrier; trial tetap memakai area di luar HFSX pada ios. Driver logging
belum memiliki target partisi terpisah; carrier juga tetap bergantung UFS/mutex
yang sama. Tidak ada mount/write carrier selama audit.

**Langkah berikutnya:** user boot image GUI-log baru, gunakan stopwatch tiga menit
setelah logo (catat perubahan/reboot lebih awal), lalu kembali ke recovery dan
forward ADB. Pull dengan SWEET_LOG_PARTITION=ios dan SWEET_ADB_BIN/HOST/PORT;
verifikasi header/flush/trial baru. Catat marker mount GPT ios dan frame/liveness.
Jika gap logger/kernel masih ada, implementasikan 0088 observer independen sesuai
roadmap. 0088 belum dibuild. Alternatif tanpa persistent log:
[0087-ios-diag 6jWRQptn](https://pixeldrain.com/u/6jWRQptn), sweetlog=0.

**Jangan pakai image logging userdata lama GnxdmsDC pada layout baru**, jangan
menggunakan offset/sda28 lama. Old userdata audit tetap historis. Script packaging
sekarang default UFS_PARTITION=ios dan menolak konflik/duplikat; script pull log
default SWEET_LOG_PARTITION=ios. Tetap pilih rd=ufsroot0 (alias BSD), ufsroot=ios
(nama GPT). Jangan menyentuh partisi Android/Windows/ESP untuk log.

Durasi tes lama dikoreksi user: mungkin sekitar tiga menit, bukan pengukuran lima.

## Riwayat hasil pada layout userdata sebelum perpindahan

**Hasil terbaru — ring log 0087-GUI-log sudah diambil:**
[analisis utama dan roadmap 0088](docs/0087_PERSISTENT_LOG_ANALYSIS.md),
[console decoded](docs/evidence/0087-gui-log-console.txt),
[metadata snapshot](docs/evidence/0087-gui-log-pull.json).
Marker IOAcceleratorES published; exec SpringBoard/backboardd masing-masing satu,
backboardd membuat surfaces 2/3 dan mengirim swap 2–6. Heartbeat terakhir yang
tersimpan **13**, timer **115978**; header hanya **flush 5**, total **47097** byte.
User kemudian memperkirakan mungkin sekitar tiga menit. Jangan menganggap snapshot
ini merekam seluruh waktu tunggu atau menyimpulkan kernel hang; bedakan worker UFS/logger/console yang
berhenti dari kernel/scheduler. Tidak ada suffix ring tambahan di luar snapshot.

Driverkitd[67] mendapat SIGKILL dengan namespace JETSAM, reason per-process memory
limit (7), lalu heartbeat/swap berlanjut. Tidak ada crash SpringBoard/backboardd
atau laporan kernel panic pada snapshot. Asal garis merah belum dipastikan:
shim memang clear RED, dan copy full-canvas menyisakan margin 12 px atas/bawah.

**Langkah berikutnya: 0088 diagnostik independen, belum dibuild.** Counter heartbeat
harus naik sebelum printf; amati counter copy-completed dan fase/errno UFS/logger.
Header liveness tetap di-flush walau ring console tidak bertambah; siapkan status
framebuffer yang tetap terbaca bila storage gagal. Detail dan batas lock/observer
ada pada roadmap analisis utama. Jangan menambah GPU/SMP, reflash root atau
menonaktifkan jetsam hanya dari log ini. Query crash-report tambahan terhenti
karena ADB kemudian timeout, termasuk get-state; tidak membuktikan filesystem rusak.

**Historis, layout userdata lama: 0087-GUI-log pernah diuji.**
[Download GnxdmsDC](https://pixeldrain.com/u/GnxdmsDC),
[langkah tes/pull log](docs/0087_RECOVERY_LOG_TRIAL.md),
[manifest](docs/evidence/0087-gui-log-build.json).
Trial `0087-gui-log-r39984162472`, SHA256
`e1dfb191b5988c8985510db70f1b03bea30dad27b53b0819bc849a3f9fae8e59`.
Kernel/shim/ADT/DTB/static init dan payload di luar command-line buffer identik
0087-GUI; hanya sweetlog=1, flush 10 detik eksplisit dan trial baru. Capture boot
sesudah logo sudah diambil; lihat hasil di atas. Image ini hanya baseline historis; bukan fallback untuk layout ios baru.

**ADB recovery berhasil diaudit read-only:** server `127.0.0.1:15037`, gunakan
`/home/rofikkernel/alpha/out/host/linux-x86/bin/adb -H 127.0.0.1 -P 15037`.
Live userdata `/dev/block/sda28` 32 GiB, logical sector 4096; HFSX di dalamnya
16 GiB. Tail 4198400 byte mulai block 8387583 berada di luar volume dan sudah
dibackup. [Bukti geometry](docs/evidence/0087-live-recovery-geometry.json).
ADB sempat terputus lalu kembali; audit file live kemudian selesai via 17 read
B-tree tanpa mount/write. `/tmp` target 01777 dan `/var/run` ada; preferensi migrasi
20H392/SyntheticDidUpgrade=false, BKNoWatchdogs dan SetupDone terkonfirmasi pada
HP. [Bukti audit live](docs/evidence/0087-live-hfs-path-audit.json). Ini bukan probe
runtime getattrlist atau fsck. User perlu kembali ke recovery setelah tes image log.

**Full log 0087-GUI sudah diterima:** [analisis utama](docs/0087_FULL_LOG_ANALYSIS.md),
[salinan transkripsi](docs/evidence/0087-full-user-transcription.txt),
[temuan terstruktur](docs/evidence/0087-full-log-findings.json).
Trial runtime terbaca `0087-gui-r39984162472`, console flag 1. Root HFS journaled
sudah mounted, UMD selesai, cache diterima launchd; heartbeat 3 → 5 → 6 terlihat
hingga fase cache loader. Foto berakhir di logo/garis merah; tidak ada observasi
heartbeat/swap sesudah logo. File ini transkripsi foto terpotong, bukan raw log.

Prioritas: **capture sesudah cache/present**, bukan reflash root atau menganggap
volume Data terpisah wajib. `dc_reset /tmp` dan `/var/run` EINVAL sudah terkonfirmasi;
audit binary menunjuk jalur realpath/getattrlist yang meminta atribut data
protection (kandidat mismatch HFS, perlu probe). Virtual random -147 terbukti
berasal dari pencarian `AppleVirtIOEntropy` yang tidak menemukan service; bukan
bukti seluruh PRNG kernel gagal. Pesan `rapportd ... nxprov_create: 1` sebelumnya
adalah EPERM Skywalk, tetapi tidak terdapat pada transkripsi baru ini.

Capture pertama sudah selesai dan terverifikasi. Lanjutkan instrumentasi 0088
untuk gap liveness/logger pada hasil baru, lalu probe atribut HFS. Kriteria
geometry untuk tail sudah dipenuhi pada HP ini; ulangi jika layout berubah.

**Referensi display Topaz sudah dibandingkan:**
[analisis source dan roadmap display](docs/TOPAZ_DISPLAY_COMPARISON.md).
Topaz 0102 memakai copy-and-flip bila back buffer tersedia; direct scanout dan GPU
rendering adalah pekerjaan berbeda. Kernel timelm 0087 sudah memiliki loop cache
maintenance nyata pada disassembly. Allocator Topaz di bawah 4 GiB tidak bisa
langsung diasumsikan cocok dengan VM HIGH timelm yang seluruhnya di atas 4 GiB.
Gunakan 0087 sebagai baseline; perbandingan ini sendiri tidak membenarkan
menulis register DPU atau mengimpor driver GPU. Roadmap lanjut: observasi present → jalur
copy ABL → audit DPU/RAM → double buffer → zero-copy opsional → GPU Adreno 650.

**Tambahan log 0086 sudah dianalisis:** [analisis dan symbolication](docs/0086_FULL_LOG_ANALYSIS.md).
Transkripsi sembilan screenshot memastikan SpringBoard PID 26 dan heartbeat/timer
bergerak di antara foto. PC/LR SpringBoard resolve ke `mach_msg2_trap` /
`mach_msg2_internal`, serta `workq_kernreturn` / `pthread_wqthread`: bukti jalur
IPC/workqueue, bukan bukti crash. Tidak ada pesan `/tmp` atau laporan `CRASH` pada
transkripsi yang terpotong ini. Gunakan sebagai konteks 0086; utamakan gap observasi
0087 pada analisis baru sebelum memilih perubahan source berikutnya.

## Status: iOS userland berjalan, GUI interaktif belum terkonfirmasi

UFS baca-tulis sudah menjalankan daemon iOS: `calaccessd`, `com.apple.datamigrator`,
`cloudd`, `installcoordinationd`, `remotepairingdeviced`, `seld`, `ind`,
`safetyalertsd` dan backboardd. Tidak reboot. User melihat layar diam sekitar lima
menit pada `IOAcceleratorES -> 0 found`. Transkripsi tambahan menunjukkan heartbeat
masih aktif selama beberapa screenshot; apakah tetap aktif setelah layar terakhir
diam belum dikonfirmasi.
[Bukti](docs/evidence/0086-ios-userland-phone-result.txt).

Jangan menyatakan kernel hang hanya dari baris terakhir: trace IOKit lama berhenti
setelah 400 baris. AKS lama mencetak setiap call; sampler juga membaca memori user
sambil memegang task_lock mulai detik ke-90. Profil baru mematikan tracing/sampling
intrusif untuk memperjelas heartbeat dan mengurangi beban framebuffer.

Milestone yang sudah dilewati:

- Timer 27, SGI1, satu CPU, BSD initialization dan static PID 1 dari `md0`.
- Watchdog-stop: static PID 1 mencapai heartbeat 70 dan terus berjalan (sekitar
  enam menit), sebelumnya reset setelah heartbeat 4. Bukti praktis kuat terhadap
  watchdog APSS sebagai penyebab reset lama; register readback/reset reason belum
  disuplai user.
- UFS membaca metadata HFS. Trial RO gagal menulis journal dengan EROFS=30 (0x1e),
  lalu EINVAL=22 dan mountroot errno=19. RW mengizinkan journal dan mencapai daemon
  iOS; tidak ada bypass journal atau reflash userdata.

Belum terbukti: GUI/SpringBoard, GPU fisik, touch/keys/USB timelm, SMP dan stabilitas
jangka panjang. Static init pada trial md0 berbeda dari launchd iOS pada trial UFS.

## Image baseline: 0087 diag dan GUI sudah dicoba

[Album kedua image](https://pixeldrain.com/l/rTmgiJB6).

| Profil | Download | Perilaku |
|---|---|---|
| **diag — mulai di sini** | [2LJ48oCg](https://pixeldrain.com/u/2LJ48oCg), `timelm-0087-ufs-rw-c1-wdtstop-diag.img` | Console dan heartbeat tetap tampil |
| GUI | [Ljk2AiJQ](https://pixeldrain.com/u/Ljk2AiJQ), `timelm-0087-ufs-rw-c1-wdtstop-gui.img` | Console dimute setelah present pertama |

```bash
fastboot boot timelm-0087-ufs-rw-c1-wdtstop-diag.img
# Setelah melihat hasil diag, jika perlu tampilan tanpa overlay:
fastboot boot timelm-0087-ufs-rw-c1-wdtstop-gui.img
```

```text
diag SHA256 7c5f15501bbec6932f3f0f74a9d39c31935ffbb6cf2172e4f97a82a2f0936623
GUI  SHA256 53a8e4f5faff615877e035ba5608c6183c5a8a7b4d15d84f0e965dae9af8ad1c
kernel      42b9033b867b5b02ff8eb2beab03a983a781f6a3c6f129c4380c9132332823c0
trials      0087-diag-r39984162472 / 0087-gui-r39984162472
```

**Kedua profil sudah dicoba user:** diag menampilkan logo; GUI sempat animasi lalu
diam dengan bar merah. Trial GUI sudah terkonfirmasi dari log. Heartbeat ada sampai
cache loader, tetapi liveness sesudah logo, GUI interaktif dan reboot belum
terkonfirmasi. Keduanya mengizinkan filesystem writes pada userdata,
memakai kernel/shim/ADT/static-init/DTB yang sama; hanya console flag dan trial ID
berbeda. Root tetap `ufsroot0`, `ufsrw=1 rootrw=1 launchd_unsecure_cache=1`;
`cpus=1`, timer 27, quiet, watchdog-stop dan probe hardware lain tetap mati.

[CI 39984162472](https://github.com/rofikkerneldev/ios_timelm/actions/runs/39984162472)
**success**, kernel commit `4ec36d14f2fc301d61d59443c2807c3146de7c7f`. 87 patch
apply, 14 regression test, kompilasi lokal dua C++ translation unit dan build XNU
macOS/post-build tests lulus. Shim Linux memakai sampai `JOBS=56`. Upload `pd upload`,
checksum server cocok. 10 segmen kernel, ADT, DTB, CI commit dan patch digest dicek.
[Manifest lengkap](docs/evidence/0087-builds.json). `source_dirty=true` saat packaging
berasal dari pembaruan JSON hasil HP; patch digest cocok dengan CI.

## Apa yang berubah pada 0087

1. **IOAcceleratorES kosong**, mengikuti ide [Topaz patch 0138](https://github.com/MakrSas/ios-topaz/blob/topaz/xnu/patches/0138-topaz-empty-ioacceleratores.patch),
   header commit `3c6b666d548c464608619f0843378404745a5d56`. Class dipublikasikan
   sebagai child AppleCLCD tanpa Metal plugin/user client. Ini compatibility match
   untuk QuartzCore, bukan GPU driver/acceleration. `sweetaccel=0` menonaktifkan.
2. **Log AKS bounded**, default 64/max 1024; profil menggunakan `sweetakslog=32`.
   Setelah batas ada satu pesan suppression. Hasil API tidak berubah; selector 10
   (wrap key) tetap unsupported. Jangan menganggap securityd/biomed sudah lengkap.
3. **Canvas konsisten dengan iPhone X/ADT: 1125x2436**, termasuk panel V60 fisik
   1080x2460. Offset tengah X=22, Y=-12; sebelumnya guard tinggi memilih native dan
   tidak cocok dengan canvas ADT. `sweetfb_native=1` adalah opt-out.
4. Profil diagnostik menggunakan `sweetiolog=- sweetsample=- sweetscan=-`, copy
   framebuffer 5 Hz (`sweetfb_hz=5`), dan `sweetfb_noconsole=0`. Profil GUI hanya
   mengganti console flag ke 1. Renderer tetap software, sehingga UI bisa lambat.

## Hasil yang harus dikumpulkan

Pada diag, rekam dari awal sampai sedikitnya dua menit setelah daemon iOS start:

```text
TIMELM GUI 0087: IOAcceleratorES compatibility service published (no GPU)
SWEET FB: ... presented as 1125x2436
TIMELM GUI 0087: AKS call log limit reached (32), results unchanged
TIMELM: trial=0087-diag-r39984162472 heartbeat=... cpu0-timer=...
```

Catat apakah heartbeat terus bertambah sesudah layar tampak diam, ada `exec
SpringBoard`/`exec backboardd`, crash (`CRASH ...`), `SWEET FB: swap ...`, dan apakah
ada frame UI. Pada GUI, console hilang setelah present pertama adalah perilaku
sengaja dan tidak membuktikan hang.

| Hasil | Langkah berikutnya |
|---|---|
| Service gagal dipublikasikan | Periksa class registration/attach pada AppleCLCD |
| Heartbeat hidup, UI belum | Fokus backboardd/SpringBoard, renderer, IOSurface/IOMFB, exec/crash pertama |
| Diag berhenti heartbeat juga | Bedakan console/display failure dari kernel/UFS/lock stall; jangan otomatis menuduh IOAcceleratorES |
| Frame swap ada, layar kosong/teks tertimpa | Coba profil GUI dan periksa crop/stride/format/surface lifetime |
| Perlu perbandingan empty service | Repack profil sama dengan `sweetaccel=0`, identifikasi trial baru |
| Error `/tmp` muncul | Catat path, teks dan errno lengkap sebelum mengubah root |

Sampler dinonaktifkan pada profil ini karena berpotensi mengganggu. Jika perlu
sampling, perbaiki cara mengambil referensi thread/VM dan batasi pengambilan
sebelum mengaktifkan kembali. Jangan membuat perubahan keybag/filesystem hanya
untuk menyembunyikan error yang belum diketahui.

## Temuan /tmp

**Update:** full log 0087 menangkap `dc_reset: /tmp: Invalid argument` dan
`dc_reset: /var/run: Invalid argument`; lihat kandidat query atribut data protection
pada [analisis baru](docs/0087_FULL_LOG_ANALYSIS.md). Bukti awal berikut tetap berlaku.
User sebelumnya menyebut error `/tmp` yang tidak sempat tercapture. Audit read-only terhadap
**image host asli** menunjukkan `/tmp -> private/var/tmp`, target root:root mode
`01777`; `/var -> private/var` juga ada. `/private/tmp` tidak ada, tetapi bukan target
symlink `/tmp`. [Audit](docs/evidence/host-root-tmp-audit.json). Ini tidak membuktikan
keadaan filesystem HP setelah boot; perlukan error aktual atau pemeriksaan recovery.
Tidak ada alasan untuk reflash/mengubah root berdasarkan pesan terpotong itu.

## Fondasi yang wajib dipertahankan

- **0085:** timer virtual INTID 27, SGI1 CPU0 `0x01000001`, CPU1 `0x01010001`;
  release/acquire stage flags, actual SGI counter, tidak mempublikasikan sukses
  semua CPU sesudah startup failure. Jangan mengembalikan encoding 0083 `0x10011`.
- **0086:** tidak menunggu 30 detik resource `IORTC` yang belum ada, tetapi tetap
  menjalankan `clock_initialize_calendar()` dengan fallback platform.
- **Watchdog-stop:** `timelm_wdt=stop`, shim `90d21f9`, base APSS `0x17c10000`,
  enable +0x08. Stop jika aktif, barrier/readback; tanpa flag tidak menyentuh MMIO.
  [Audit driver vendor/mainline](docs/evidence/watchdog-source-audit.json). Tidak
  mengubah reset/timeout, PMIC, secure world. Sebab hardware lengkap belum diaudit.
- Baseline 0087 memakai `sweetlog=0`; varian **GUI-log memakai sweetlog=1** sesudah
  audit recovery membuktikan tail di luar volume dan backup selesai. Cocokkan
  trial/flush setiap pull; jangan menganggap ring lama hasil trial baru. Audit
  geometry diulang jika volume/partisi diresize.
- Keys/touch/USB fisik tetap off. HID/battery registration masih stub. SMP ditunda.
- HIGH `[0x100000000,0x270000000)`, 5.75 GiB. LOW lama tidak 32-MiB aligned.
  DTB statis `/memory` ukuran nol tidak membuktikan runtime RAM 8/12 GB.

## Workspace dan fallback

Repo `/home/rofikkernel/xnu/ios-timelm`, Debian 12 tanpa GUI. Simpan scratch di
`$HOME/work/`, hindari `/tmp` sesuai preferensi user. Git push SSH tersedia; `gh`
lokal belum login. GitHub connector dapat membaca job logs/download artifacts.

- Kernel aktif: `xnu/out/kernel.development.sweet` = **0087**; CI provenance di
  `xnu/out/build-provenance.json`.
- Source lengkap: `$HOME/work/timelm-0087/verify`; artifacts/build logs di
  `$HOME/work/timelm-0087/`; metadata/image hashes juga di `shim/out/*.img.json`.
- Backup kernel 0086: `$HOME/work/timelm-0087/kernel-before0087.sweet`.
- [Fallback 0086 UFS-RW](https://pixeldrain.com/u/G1CYVE4s) = daemon iOS sudah berjalan.
- [Fallback RAM-disk watchdog-stop](https://pixeldrain.com/u/acwZLzob) = static PID 1
  heartbeat 70. [Riwayat roadmap](docs/TIMELM_BOOT_ROADMAP.md).

Saat repack, mulai dari command line manifest aktif dan pertahankan watchdog-stop
**secara eksplisit**; default script tidak menambahkan flag itu. Kernel marker IRQ
masih `0085` dan marker RTC masih `0086`, karena diwariskan. Gunakan trial ID/hash/
marker GUI 0087 untuk mengidentifikasi build.

Root iOS sudah berada di userdata dan journal/write path telah melewati mount.
Jangan rebuild/reflash image 12 GB untuk setiap iterasi kernel. UFS masih memiliki
asumsi LUN0/blok 4K/DMA/SMMU yang perlu diuji lebih jauh bila muncul error I/O nyata,
namun log GUI terakhir tidak membuktikan transport storage sebagai penghambat.
