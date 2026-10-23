# Handoff berikutnya untuk OpenCode — LG V60 / timelm

Tanggal: 2026-10-23. Mulai dari file ini agar tidak mengulang investigasi sebelumnya.

## UPDATE TERBARU: reboot setelah sekitar 30 detik, uji image quiet dahulu

User melaporkan **ketiga image 0085 awal** mencetak banyak
`kernel_startup_initialize_upto[7, rank -1]: <alamat>(<alamat>)`, framebuffer lambat,
lalu reboot sekitar 30 detik. Belum ada foto/alamat terakhir atau panic yang
teridentifikasi. Source XNU membuktikan baris itu adalah verbose startup tracing:
subsystem 7 = ZALLOC, rank -1 = `STARTUP_RANK_LAST`, dan alamatnya callback/argumen.
Kernel CI memiliki 872 callback ZALLOC (803 rank LAST), serta 2182 callback SYSCTL.

Semua image awal memakai `startup_debug=1`. Ini menambah beban console dan menjadi
variabel pertama yang harus diisolasi. Penyebab reboot **belum dipastikan**;
kemungkinan watchdog atau exception nyata tetap terbuka.

**Image berikutnya yang harus diuji:**
[timelm-0085-rd-c1-quiet.img](https://pixeldrain.com/u/bz3c6qFV).

```text
SHA256 a6b51a316687d4b88aaa470129feaf0fc3ad84d4b616e642282a7a4a0570dc39
trial  0085-rd-quiet-r39968689712
```

```bash
fastboot boot timelm-0085-rd-c1-quiet.img
```

Kernel tidak dibuild ulang. Perbandingan byte memastikan kernel, ADT, static init,
shim dan DTB sama dengan image rd awal; hanya `startup_debug=0` dan trial ID yang
berubah. [Manifest quiet](docs/evidence/0085-quiet-build.json). Default script build
sekarang `startup_debug=0`; trace BSD dan heartbeat tetap tersedia.

Jika quiet melewati tahap ini, lanjutkan baseline RAM-disk sampai PID 1 dan baru
buat varian UFS quiet bila diperlukan. Jangan langsung mengulang kedua image UFS
verbose lama. Jika quiet tetap reboot sekitar durasi yang sama, rekam video layar
dan periksa reset reason/watchdog Qualcomm yang diwariskan firmware. `wdt=-1`
dan stub IOWatchdog XNU tidak membuktikan watchdog hardware Qualcomm dinonaktifkan.
Jika ada alamat callback terakhir yang konsisten, petakan ke simbol kernel CI
dan instrumen entry/exit callback tersebut secara terbatas.

## Status yang sudah selesai

- Analisis awal: [TIMELM_BOOT_ROADMAP.md](docs/TIMELM_BOOT_ROADMAP.md).
- Perbaikan software 0085 sudah diimplementasikan, di-commit, dan dibuild.
- Commit kode/kernel: `2c82298cb806c785fbdb600048baf0247f596bec`.
- [CI run 39968689712](https://github.com/rofikkerneldev/ios_timelm/actions/runs/39968689712)
  selesai **success**, termasuk tes SGI dari source kernel setelah build.
- 85 patch berhasil diterapkan ulang; 12 regression test lulus. Tujuh translation
  unit kernel juga lulus pemeriksaan kompilasi lokal dengan header hasil CI.
- Tiga boot image selesai, semua segmen XNU dibandingkan byte demi byte dengan
  kernel CI, ADT di dalam image cocok dengan DTB, dan checksum upload diverifikasi.
- Upload dilakukan menggunakan `pd upload`, sesuai permintaan user.
- **Image awal sudah dilaporkan reboot oleh user; quiet belum diuji. Belum ada bukti PID 1, launchd, atau SpringBoard pada 0085.**
- Userdata iOS sudah diflash sebelumnya. Tidak ada flash/boot HP pada sesi ini.

## Download dan file lokal

[Album seluruh boot image](https://pixeldrain.com/l/BMRkvoVC).

| Urutan | File | Pixeldrain | Tujuan |
|---|---|---|---|
| 1 | `timelm-0085-rd-c1.img` | [Ko5ZLimb](https://pixeldrain.com/u/Ko5ZLimb) | RAM-disk static init, membuktikan timer dan PID 1 |
| 2 | `timelm-0085-ufs-ro-c1.img` | [Hif51ceZ](https://pixeldrain.com/u/Hif51ceZ) | Diagnosis UFS/HFS dengan penulisan blok ditolak |
| 3 | `timelm-0085-ufs-rw-c1.img` | [vopqD6dy](https://pixeldrain.com/u/vopqD6dy) | Mencoba root iOS dan launchd; userdata writable |

Semua image: **16,941,056 byte**, HIGH RAM `[0x100000000, 0x270000000)`, **cpus=1**,
virtual timer **27**, serta `sweetkeys=0 sweettouch=0 sweetusb=0 sweetlog=0`.
HIGH window berukuran **5.75 GiB**, bukan 3.7 GiB.

```text
84988b681c3aace7b0d2447643e3da242b64467501455377e828a054a4e16467  timelm-0085-rd-c1.img
3c2fbd4d9de94b95c4a396145aa637b4e95d0a3725ea38ea0ed7a91da3e9d5d6  timelm-0085-ufs-ro-c1.img
5a55078cad4e7eb40e3f50b5576142cc1f3a0ca54a04c133bde383d713c6e803  timelm-0085-ufs-rw-c1.img
```

Lokasi di server:

- Repo: `/home/rofikkernel/xnu/ios-timelm`.
- Image dan manifest: `shim/out/timelm-0085-*.img`, `.img.json`, `.img.sha256`.
- Kernel: `xnu/out/kernel.development.sweet`, SHA-256
  `fed41d3b653d6def101a6477891d9c3e99dde45f306c1b3b98e4dbe56ee63e14`.
- Provenance CI: `xnu/out/build-provenance.json`.
- [Ringkasan artifact dan link](docs/evidence/0085-builds.json).
- Source hasil rekonstruksi: `/home/rofikkernel/work/timelm-0085/verify`.
- Backup kernel sebelum 0085: `/home/rofikkernel/work/timelm-0085/kernel-before0085.sweet`.
- Log build image dan upload: `/home/rofikkernel/work/timelm-0085/`.
- Panduan lebih lengkap: [TIMELM_0085_TEST.md](docs/TIMELM_0085_TEST.md).

Manifest menunjukkan `source_dirty=true` karena panduan tes Markdown sedang
ditulis saat packaging. Patch digest telah dicocokkan dengan artifact CI; kode
kernel/shim yang dibuild sesuai commit di atas.

## Mengapa build ini dibuat

DTB LG V60 memiliki virtual timer PPI 11, yaitu INTID **27**, sedangkan port lama
menggunakan **19**. Ini kandidat utama penyebab sleep/timeout tidak bangun, termasuk
`IOSleep(1)` pada SMP dan penantian RTC sesudah BSD buffer initialization.
Konflik konfigurasi terkonfirmasi; sebab hang di HP masih memerlukan tes fisik.

Patch 0083 juga salah mengubah INTID SGI dari shift 24 ke shift 4. Perbaikan 0085
mengembalikan encoding yang benar, menghapus write group-enable GICR yang tidak
valid, memakai release/acquire untuk stage flags, dan mensyaratkan SGI1 benar-benar
diterima sebelum CPU diumumkan siap. Kegagalan CPU tidak lagi dipublikasikan sebagai
sukses semua CPU. Penghitungan interrupt tidak mencetak console dari handler IRQ.

0085 menambahkan counter timer/SGI1 pada heartbeat, trial ID, marker keluar dari
penantian RTC, trace sebelum mapping/alokasi UFS, dan scroll console per delapan
baris untuk mengurangi penyalinan framebuffer. Default build sekarang HIGH/cpus=1,
ADT selalu dibuat baru, dan command line terlalu panjang ditolak.

## Prioritas selanjutnya: tes HP, lalu perbaiki berdasarkan milestone

Jalankan di komputer yang terhubung dengan HP dalam fastboot:

```bash
fastboot boot timelm-0085-rd-c1.img
```

Tunggu **minimal 90 detik**. Rekam layar penuh, terutama trial ID dan baris terakhir.
Marker yang dicari:

```text
TIMELM IRQ FIX 0085: trial=0085-rd-r39968689712 timer=27 CNTFRQ=...
SWEET CPU: cpu=0 ... SGI1 received=... timer-irqs=...
bsd_init: returned from IOKitInitializeTime
TIMELM: trial=0085-rd-r39968689712 heartbeat=... cpu0-timer=... cpu0-sgi1=...
*** SWEET userspace: init running as PID 1 ***
SWEET init: still alive
```

Jumlah timer harus bertambah dan pesan alive muncul kira-kira setiap lima detik.
Static init ini membuktikan transisi ke userspace, **bukan Apple's launchd**.
Setelah rd sukses, uji `ufs-ro`; setelah transport/filesystem tervalidasi, uji
`ufs-rw` untuk iOS userland. Detail urutan ada di panduan tes.

| Hasil terbaru | Tindakan OpenCode berikutnya |
|---|---|
| Berhenti pada CPU wait / panic SGI | Periksa SGI1, DAIF, ICC_SRE/PMR/IGRPEN1, affinity GICR dan pending bits |
| Berhenti di `IOKitInitializeTime`, timer tidak bertambah | Periksa routing timer runtime, CNTV_CTL/CVAL, CNTFRQ dan penantian scheduler |
| rd berjalan, ufs-ro gagal sebelum SCSI | Periksa HCE/HCS/CAP, takeover host, alokasi DMA, SMMU firmware |
| Command SCSI gagal | Temukan LUN dan ukuran blok aktual; periksa OCS/sense/doorbell/DMA |
| UFS membaca, GPT/userdata tidak ditemukan | Validasi LUN, GPT CRC/entry/bounds dan kapasitas aktual |
| HFS mount gagal | Periksa HFS header/journal; pisahkan kerusakan FS dari kegagalan transport |
| HFS ter-mount, launchd gagal | Cari errno/exception pertama pada exec, dyld/shared cache dan permission |
| launchd stabil, GUI belum tampil | Periksa backboardd/SpringBoard, IOSurface/IOMFB dan geometri display |

Kumpulkan hash image, trial ID, command line, lama menunggu, milestone terakhir,
error pertama dan foto/video sebelum mengubah kernel berikutnya. Jika tidak ada
hasil HP baru, lanjutkan pekerjaan host yang relevan dan jelaskan batas buktinya;
jangan menyimpulkan boot sukses dari keberhasilan CI saja.

## Batas dan pekerjaan yang sengaja menunggu bukti HP

- Jangan memakai image 0083/0084 sebagai image perbaikan saat ini. Riwayat log lama
  ada di `docs/evidence/`; urutan layar lama bisa wrap dan kehilangan baris awal.
- `sweetlog=0`: log persisten di userdata tidak diperbarui oleh image ini. Hasil
  `sweet-log-pull` yang lama tidak membuktikan trial 0085.
- Pertahankan userdata yang sudah diflash. Reflash hanya jika ada bukti korupsi
  atau perubahan root yang memang diperlukan. `fastboot boot` image ufs-rw tetap
  memungkinkan kernel/iOS menulis userdata meskipun boot partition tidak diflash.
- Driver UFS masih mengasumsikan LUN0/4K dan link dari ABL. SMMU, DMA di atas 4 GiB,
  GPT CRC dan geometri storage perlu divalidasi bila fase UFS gagal.
- Touch/keys/USB fisik belum diport lengkap ke V60. Jangan mengaktifkannya hanya
  karena HID stub terdaftar. SMP 2/4/8 CPU dilakukan sesudah baseline satu CPU stabil.
- LOW base tidak 32-MiB aligned dan ditolak packer sekarang. Klaim lama bahwa LOW
  crash pasti akibat bank boundary belum terbukti. DTB statis `/memory` berukuran
  nol; gunakan runtime map untuk memvalidasi RAM board 12 GB maupun stock 8 GB.

## Build selanjutnya bila dibutuhkan

Server Debian 12 tanpa GUI. Simpan build di `$HOME/work/`, hindari `/tmp` sesuai
preferensi user. User mengizinkan paralelisme sampai `-j56` pada server. Full XNU
proyek ini memakai CI macOS/Xcode; shim Linux menerima `JOBS=56` dan memiliki tujuh
translation unit independen. Git push lewat SSH tersedia; `gh` lokal belum login.
GitHub connector dapat membaca job log dan mendownload artifact bila tersedia.

```bash
cd /home/rofikkernel/xnu/ios-timelm
TMPDIR="$HOME/work/timelm-0085/tmp" XNU_SOURCE="$HOME/work/timelm-0085/verify" \
  python3 tools/test_timelm_boot.py -v
python3 tools/validate-repo.py
# Setelah edit patch: rekonstruksi ulang source dengan tools/verify-patches.sh.
# Build kernel melalui workflow xnu.yml, ambil artifact dari commit/run yang tepat.
JOBS=56 PROFILE=rd TRIAL=NEXT-rd-test1 tools/build-boot.sh high timelm-NEXT-rd-c1.img
pd upload shim/out/timelm-NEXT-rd-c1.img
```

Periksa checksum artifact serta commit/patch digest sebelum mengganti kernel.
Jangan mengambil release `latest` tanpa memastikan provenance-nya. Setiap output
boot image harus lolos `tools/inspect_boot.py` dan disertai manifest/checksum.
