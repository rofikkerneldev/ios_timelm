# Handoff OpenCode — LG V60 / timelm

Checkpoint terbaru 2026-10-23. Baca file ini dahulu; riwayat ada di `docs/evidence/`.

**Update 0087-GUI:** logo sempat animasi lalu diam, bar merah tetap terlihat;
sesudah jeda ada `__nexus_register` / `rapportd(82): nxprov_create: 1` menurut
transkripsi user. Full log akan dikirim. [Analisis source](docs/0087_GUI_LOG_ANALYSIS.md):
errno 1 = EPERM pada jalur jaringan Skywalk; PID 82 adalah rapportd. Belum ada
bukti hubungan kausal dengan UI berhenti. Prioritas berikutnya membaca full log,
menentukan liveness/swap dan perilaku console sebelum build/perubahan baru.

Tambahan diag: user membaca kira-kira `failed to load virtual random`, `tmo`, dan
`pu0-sgil-1`; belum ada teks lengkap. Heartbeat tidak lagi terlihat, mungkin ada
sebelum animasi. Jangan menganggap heartbeat berhenti atau RNG/ramdisk/tmp rusak.
Jika baris terakhir adalah `cpu0-sgi1=1`, ini counter satu SGI1 ditangani, bukan
error, dan tidak wajib terus bertambah pada cpus=1. Full log masih akan dikirim.

**Laporan HP terbaru — 0087-diag:** user mengonfirmasi image
`timelm-0087-ufs-rw-c1-wdtstop-diag.img`; logo Apple terlihat, sekitar lima baris
`exec xpcproxy`, dan bar merah di bawah. User masih menunggu progres boot.
[Catatan hasil sementara](docs/evidence/apple-logo-phone-report.txt).
Durasi akhir, heartbeat/swap dan reboot belum dikonfirmasi. Asal bar merah belum
diidentifikasi. Jangan menandai GUI interaktif berhasil atau crash loop dari
informasi ini; pesan `exec` sendiri bukan error.

**Referensi display Topaz sudah dibandingkan:**
[analisis source dan roadmap display](docs/TOPAZ_DISPLAY_COMPARISON.md).
Topaz 0102 memakai copy-and-flip bila back buffer tersedia; direct scanout dan GPU
rendering adalah pekerjaan berbeda. Kernel timelm 0087 sudah memiliki loop cache
maintenance nyata pada disassembly. Allocator Topaz di bawah 4 GiB tidak bisa
langsung diasumsikan cocok dengan VM HIGH timelm yang seluruhnya di atas 4 GiB.
Tetap tes image 0087 berikut dahulu; belum ada alasan dari perbandingan ini untuk
build baru atau menulis register DPU. Roadmap lanjut: observasi present → jalur
copy ABL → audit DPU/RAM → double buffer → zero-copy opsional → GPU Adreno 650.

**Tambahan log 0086 sudah dianalisis:** [analisis dan symbolication](docs/0086_FULL_LOG_ANALYSIS.md).
Transkripsi sembilan screenshot memastikan SpringBoard PID 26 dan heartbeat/timer
bergerak di antara foto. PC/LR SpringBoard resolve ke `mach_msg2_trap` /
`mach_msg2_internal`, serta `workq_kernreturn` / `pthread_wqthread`: bukti jalur
IPC/workqueue, bukan bukti crash. Tidak ada pesan `/tmp` atau laporan `CRASH` pada
transkripsi yang terpotong ini. Tetap tes 0087-diag; jangan membangun kernel baru
hanya karena log lama mengulang IOAcceleratorES -> 0 found.

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

## Image aktif berikutnya: 0087 diag dahulu, lalu GUI

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
diam dengan bar merah dan pesan Nexus di atas. GUI interaktif, durasi akhir,
liveness dan reboot belum terkonfirmasi. Keduanya mengizinkan filesystem writes pada userdata,
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

User menyebut error `/tmp` yang tidak sempat tercapture. Audit read-only terhadap
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
- `sweetlog=0`: persistent log userdata tidak diperbarui. Jangan menarik log lama
  sebagai trial baru. Verifikasi tail di luar volume sebelum mengaktifkannya.
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
