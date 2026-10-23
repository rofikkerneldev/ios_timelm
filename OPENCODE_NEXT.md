# Handoff OpenCode — LG V60 / timelm

Diperbarui 2026-10-23. Mulai dari checkpoint ini; investigasi lama tidak perlu diulang.

## UPDATE TERBARU: iOS launchd/daemons dan backboardd sudah berjalan

Trial UFS-RW mencapai `exec calaccessd`, `com.apple.datamigrator`, `cloudd`,
`installcoordinationd`, `remotepairingdeviced` dan backboardd. Tidak reboot, tetapi
layar diam sekitar lima menit dengan `IOAcceleratorES -> 0 found` berulang.
[Bukti](docs/evidence/0086-ios-userland-phone-result.txt). UFS/HFS root writable
dan userland iOS sekarang terbukti; SpringBoard/GUI belum. Heartbeat setelah
layar diam belum dikonfirmasi, jadi jangan menyatakan kernel deadlock dari layar.

Patch 0087 menambahkan layanan kompatibilitas **IOAcceleratorES kosong**, berdasarkan
[patch Topaz 0138](https://github.com/MakrSas/ios-topaz/blob/topaz/xnu/patches/0138-topaz-empty-ioacceleratores.patch).
Tanpa Metal properties/user client; bukan driver GPU. `sweetaccel=0` menonaktifkan
layanan untuk perbandingan. Log AKS dibatasi `sweetakslog` (default 64, max 1024)
tanpa mengubah hasil selector, termasuk unsupported securityd selector 10.
Canvas sekarang konsisten dengan ADT/iPhone X 1125x2436, termasuk panel V60 yang
lebih tinggi; physical scanout tetap 1080x2460. `sweetfb_native=1` adalah opt-out.

Profil diagnostik berikutnya mematikan matching spam (`sweetiolog=-`) dan sampler/
heap scan (`sweetsample=- sweetscan=-`), membatasi AKS, menurunkan copy framebuffer
ke 5 Hz, serta tetap memperlihatkan heartbeat/console. Profil GUI alternatif
`sweetfb_noconsole=1` akan menyembunyikan console setelah frame pertama; jangan
mengartikan console berhenti pada profil itu sebagai hang.

Pesan `/tmp` belum tercapture. [Audit read-only image host](docs/evidence/host-root-tmp-audit.json)
menemukan `/tmp -> private/var/tmp`, target root:root `01777` (benar). Ini bukan
audit live filesystem HP. Jangan reflash/mengubah root tanpa teks error/path/errno
yang tepat. Jika perlu akses recovery, lakukan pemeriksaan metadata pada filesystem
yang tidak sedang dipakai XNU. Jangan mengubah cache/journal secara spekulatif.

## Checkpoint terbaru: RAM-disk PID 1 bertahan sampai heartbeat 70

User melaporkan image `0086-rd-wdtstop-r39974714520` menjalankan static PID 1 dan
heartbeat sudah **70 serta terus bertambah**, sekitar 350 detik. Log tertulis
memperlihatkan heartbeat 1–18, timer IRQ bertambah, dan `SWEET init: still alive`.
[Bukti](docs/evidence/0086-wdtstop-stable-phone-result.txt).

Sebelumnya kernel yang sama tanpa watchdog-stop reset sesudah heartbeat 4.
Perubahan watchdog APSS memberi bukti praktis kuat terhadap penyebab reset lama.
Nilai register before/after dan reset reason belum disuplai, sehingga audit sebab
reset hardware belum lengkap. Jangan mengklaim semua watchdog atau stabilitas SMP
sudah tervalidasi.

**Sudah terbukti pada HP:** satu CPU, timer 27, SGI1, BSD initialization, root `md0`,
devfs, static userspace PID 1, syscall dan timed sleep selama beberapa menit.
**UFS reads dan metadata HFS juga sudah tercapai**, tetapi full HFS mount masih
menunggu journal writable. Belum terbukti: Apple's launchd, SpringBoard, SMP,
driver fisik input/network dan stabilitas jangka panjang. PID 1 yang sekarang adalah init kecil
dari `tools/sweet-init.S`, bukan launchd Apple.

## Checkpoint storage: UFS membaca HFS; journal ditolak karena read-only

Trial `0086-ufs-ro-wdtstop-r39974714520` telah diuji. Log menunjukkan
`BSD root: ufsroot0, major 2, minor 0`, pembacaan metadata HFS dan percobaan
inisialisasi journal pada offset `0x82000`, ukuran `0x800000`.
[Bukti dan pemetaan source](docs/evidence/0086-ufs-ro-phone-result.txt).

Kegagalan pertama adalah `do_jnl_io: strategy err 0x1e`: **EROFS=30**, sesuai
`ufsrw=0` yang menolak write buffer. Journal gagal dibuat, HFS mengembalikan
EINVAL=22, lalu loop mount root mencetak errno=19. Ini belum membuktikan volume
korup. HFS root dapat mencoba journal initialization walau root read-only;
shortcut journal bersih untuk non-root mengecualikan `MNT_ROOTFS`.

## Tes berikutnya: UFS baca-tulis untuk journal dan launchd iOS

[Download timelm-0086-ufs-rw-c1-wdtstop.img](https://pixeldrain.com/u/G1CYVE4s).

```bash
fastboot boot timelm-0086-ufs-rw-c1-wdtstop.img
```

```text
SHA256 9b6582183c7ef6e069d0e49a17b97a32d829090574a9b2cf1c84fd082c5e4dd1
trial  0086-ufs-rw-wdtstop-r39974714520
```

Kernel, shim, ADT, static-init segment dan DTB identik dengan trial RO. Hanya
`ufsrw=1 rootrw=1 launchd_unsecure_cache=1` dan trial ID berubah. Tetap satu CPU,
timer 27, quiet, watchdog-stop, keys/touch/USB probe dan sweetlog mati.
**Image RW belum diuji di HP.** Boot ini mengizinkan penulisan filesystem/journal
pada userdata; tidak mem-flash ulang image atau boot partition. Pemeriksaan journal
dan batas partisi tetap dipertahankan. Keberhasilan write UFS belum terbukti.

Catat log mulai UFS/journal sampai error pertama atau proses launchd. Target:

- Journal initialization tidak lagi gagal dengan EROFS.
- HFS root berhasil mount dan BSD melewati `vfs_mountroot`.
- `/sbin/launchd` dari volume iOS berhasil exec; ini berbeda dari static init md0.
- Identifikasi daemon/exception pertama bila userland belum melanjutkan ke UI.

| Titik gagal berikutnya | Arah diagnosis |
|---|---|
| Write SCSI timeout/OCS/sense | Jalur write DMA/cache/SMMU, actual logical block size/LUN |
| Journal masih EROFS | Pastikan trial ID dan embedded flags RW, jangan memakai image RO lama |
| Journal/HFS EINVAL setelah write berhasil | Validasi JIB/header/journal, jangan bypass check untuk menyembunyikan error |
| HFS mount sukses, exec gagal | errno/exception pertama, dyld/cache/permission |
| launchd berjalan, belum GUI | backboardd/SpringBoard dan IOSurface/IOMFB |

Tidak perlu reflash userdata berdasarkan log RO ini. Jika ada kerusakan nyata,
buktikan melalui metadata/fsck sebelum memilih perbaikan filesystem.

## Artifact aktif dan fallback

| Artifact | Lokasi/download | Status |
|---|---|---|
| RAM-disk watchdog-stop | [acwZLzob](https://pixeldrain.com/u/acwZLzob), `shim/out/timelm-0086-rd-c1-wdtstop.img` | PID 1 sampai heartbeat 70 dilaporkan user |
| UFS read-only watchdog-stop | [fvpL6Dpf](https://pixeldrain.com/u/fvpL6Dpf) | HFS/journal terbaca; mount gagal EROFS |
| UFS read-write watchdog-stop | [G1CYVE4s](https://pixeldrain.com/u/G1CYVE4s), `shim/out/timelm-0086-ufs-rw-c1-wdtstop.img` | Trial berikutnya, belum dites |
| Kernel 0086 | `xnu/out/kernel.development.sweet` | CI sukses dan baseline fisik diuji |

```text
RAM-disk SHA256 ca0b941ef2e8535550e10595e78a2fb8dbdc170ae6948ea7fef1248153bff71e
Kernel SHA256   aa2a737c5b79f2b5102d47cac5bc7f99faf3a9008d314bfcef1066be862da9a8
Kernel commit   beaed0f90ed9fd286ee6ccadb1741dbde6d2b99f
Shim code       90d21f99042ec2f9354c84f0aba0b2c20a4de313
```

[CI 39974714520](https://github.com/rofikkerneldev/ios_timelm/actions/runs/39974714520)
berhasil. 86 patch apply; 13 regression test termasuk encoder SGI aktual dan gate/
register watchdog lulus. Kernel dibuild di macOS CI, shim lokal sampai `JOBS=56`.
Image diinspeksi: 10 segmen kernel, ADT, DTB, provenance dan checksum upload cocok.
Upload menggunakan `pd upload`.

Manifest: [RAM-disk](docs/evidence/0086-wdtstop-build.json),
[UFS RO](docs/evidence/0086-ufs-ro-wdtstop-build.json),
[UFS RW](docs/evidence/0086-ufs-rw-wdtstop-build.json). File `.img.json` dan
`.img.sha256` juga berada di `shim/out/`.

## Perbaikan yang harus dipertahankan

- **0085:** virtual timer 27 dari DTB timelm, bukan 19 warisan SWEET. Encoding SGI
  benar: CPU0 SGI1 `0x01000001`, CPU1 `0x01010001`. Stage flags release/acquire;
  sukses startup mensyaratkan SGI1 diterima, kegagalan tidak dipublikasikan sukses.
- **0086:** lewati penantian 30 detik terhadap resource `IORTC` yang drivernya belum
  ada. Tetap jalankan `clock_initialize_calendar()` memakai fallback platform.
- **Quiet:** `startup_debug=0`. Verbose lama mencetak 872 callback ZALLOC dan
  ribuan callback lain sehingga framebuffer lambat. `[7, rank -1]` adalah trace
  startup ZALLOC/rank LAST, bukan diagnosis panic.
- **Watchdog:** boot-arg `timelm_wdt=stop` mengaktifkan handoff shim di
  `shim/watchdog.h` dan `shim/loader.c`. Base APSS `0x17c10000`, EN +0x08.
  Jika enable aktif, write 0, barrier, baca kembali. Tidak mengubah reset/timeout,
  PMIC atau secure-world registers. Tanpa flag, shim tidak mengakses watchdog.
  [Audit driver vendor LG dan mainline](docs/evidence/watchdog-source-audit.json).
- Marker IRQ tetap bertuliskan `TIMELM IRQ FIX 0085`, walau kernel kini 0086.
  Identifikasi trial dari ID, hash dan marker RTC 0086.

## Batas penting saat melanjutkan

- Pertahankan `cpus=1` sampai root iOS terbukti; SMP bukan prasyarat percobaan ini.
- Userdata dilaporkan sudah berisi root iOS. Validasi lewat pembacaan, bukan reflash
  berulang. Root builder lama melaporkan volume HFS 16 GiB yang sehat; isi aktual
  di HP belum dibandingkan kembali.
- Driver UFS masih mengasumsikan LUN0 dan blok 4096 byte. MMIO cocok tidak menjamin
  DMA/SMMU benar; DTB mengiklankan stream UFS 0xe0/0x4e0. UFS memakai bounce buffer
  fisik contiguous dan dapat dialokasikan di atas 4 GiB.
- `sweetlog=0` berarti log persisten userdata tidak diperbarui. Jangan membaca log
  lama sebagai hasil trial baru. Verifikasi area tail di luar filesystem sebelum
  mengaktifkan logging ke disk.
- HID/battery yang terdaftar masih stub. Probe keys/touch/USB fisik mati untuk
  menghindari hardware SWEET yang belum diport. Jangan mengaktifkannya bersamaan
  dengan eksperimen storage.
- HIGH adalah `[0x100000000,0x270000000)`, 5.75 GiB. LOW base lama tidak 32-MiB
  aligned dan kini ditolak packer. DTB statis `/memory` berukuran nol; jangan
  menyimpulkan runtime RAM 8/12 GB hanya dari file itu.

## Workspace dan build berikutnya

Repo `/home/rofikkernel/xnu/ios-timelm`, server Debian 12 tanpa GUI. Gunakan
`$HOME/work/` dan hindari `/tmp`, sesuai preferensi user. Git push SSH tersedia;
`gh` lokal belum login. GitHub connector dapat membaca log/download artifact.
Source XNU lengkap rekonstruksi: `$HOME/work/timelm-0086/verify`. Header/compile
context lama: `$HOME/work/timelm-0085/buildtree`. Backup kernel di folder build.

Untuk image berikutnya, mulai dari command line manifest aktif dan **pertahankan
`timelm_wdt=stop` secara eksplisit**. Default umum script tidak menambahkan flag
ini; menyalin default saja bisa mengembalikan reset lama. Pasang kernel CI dari
commit/run tepat, cocokkan patch digest dan checksum, lalu inspect semua payload.
Tidak perlu build ulang kernel apabila hanya root mode yang berubah.

Baca [roadmap analisis lengkap](docs/TIMELM_BOOT_ROADMAP.md) bila diperlukan.
Riwayat bukti tersimpan di `docs/evidence/`: 0085 quiet reboot pada RTC,
0086 mencapai PID 1 tetapi reset, lalu watchdog-stop bertahan sampai heartbeat 70.
Checkpoint ini menjadi acuan terbaru; klaim "belum dites" pada dokumen historis
merujuk waktu dokumen tersebut dibuat.
