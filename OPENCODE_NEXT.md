# Handoff OpenCode — LG V60 / timelm

Diperbarui 2026-10-23. Mulai dari checkpoint ini; investigasi lama tidak perlu diulang.

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
**Belum terbukti:** UFS/HFS root iOS, Apple's launchd, SpringBoard, SMP, driver fisik
input/network dan stabilitas jangka panjang. PID 1 yang sekarang adalah init kecil
dari `tools/sweet-init.S`, bukan launchd Apple.

## Tes berikutnya: UFS baca-saja dengan kernel dan shim yang sudah diuji

[Download timelm-0086-ufs-ro-c1-wdtstop.img](https://pixeldrain.com/u/fvpL6Dpf).

```bash
fastboot boot timelm-0086-ufs-ro-c1-wdtstop.img
```

```text
SHA256 a36fe2ef1895b5e64e307e5428ede54d149472f4b18a1635eb9eda521d4a4869
trial  0086-ufs-ro-wdtstop-r39974714520
```

Perbandingan byte membuktikan kernel, shim, ADT, static-init segment dan DTB sama
persis dengan baseline watchdog-stop yang sudah diuji. Hanya root arguments dan
trial ID berubah: `rd=ufsroot0 ufsrw=0 rootrw=0`. Tetap `cpus=1`, timer 27,
`startup_debug=0`, `timelm_wdt=stop`, dan probe keys/touch/USB serta sweetlog mati.
Penulisan blok userdata ditolak. **Image UFS ini belum diuji pada HP.**

Ambil log layar penuh, termasuk trial ID, urutan UFS pertama dan error pertama.
Marker yang dicari:

```text
SWEET: IOFindBSDRoot: probing the UFS for the root volume
SWEET UFS: mapping host PA=...
SWEET UFS: allocating contiguous DMA memory
SWEET UFS: taking over the host at ...
SWEET UFS: host taken over, sending TEST UNIT READY
SWEET UFS: looking for partition "userdata"
SWEET UFS: "userdata" on LUN ...
BSD root: ufsroot0, major ...
```

Lalu cari keberhasilan HFS mount dan kelanjutan BSD. Layanan iOS mungkin gagal
pada root baca-saja; tujuan trial ini membuktikan transport dan filesystem.
Setelah storage/volume tervalidasi, siapkan UFS baca-tulis dengan kernel/shim sama,
`ufsrw=1 rootrw=1 launchd_unsecure_cache=1`, untuk mencoba launchd iOS sebenarnya.
Tidak perlu flash ulang userdata untuk mengganti kernel/boot image.

| Titik gagal | Arah diagnosis |
|---|---|
| Mapping/alokasi DMA | MMIO map, contiguous allocation, physical address |
| Host takeover | HCE/HCS/CAP/list state dan keadaan link dari ABL |
| Command SCSI | OCS/sense, DMA/cache/SMMU, logical block size dan LUN |
| GPT/userdata | LUN aktual, capacity, GPT header/CRC/entry/bounds |
| HFS mount | Header HFS, journal dan kebutuhan recovery; bedakan dari transport |
| Root ter-mount, exec gagal | errno/exception pertama, dyld/cache/permission |
| launchd berjalan, belum GUI | backboardd/SpringBoard dan IOSurface/IOMFB |

## Artifact aktif dan fallback

| Artifact | Lokasi/download | Status |
|---|---|---|
| RAM-disk watchdog-stop | [acwZLzob](https://pixeldrain.com/u/acwZLzob), `shim/out/timelm-0086-rd-c1-wdtstop.img` | PID 1 sampai heartbeat 70 dilaporkan user |
| UFS read-only watchdog-stop | [fvpL6Dpf](https://pixeldrain.com/u/fvpL6Dpf), `shim/out/timelm-0086-ufs-ro-c1-wdtstop.img` | Belum dites di HP |
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
[UFS RO](docs/evidence/0086-ufs-ro-wdtstop-build.json). File `.img.json` dan
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
