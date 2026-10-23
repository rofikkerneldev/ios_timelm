# Handoff berikutnya untuk OpenCode — LG V60 / timelm

Tanggal: 2026-10-23. Mulai dari file ini agar tidak mengulang investigasi sebelumnya.

## IMAGE AKTIF BERIKUTNYA: 0086 dengan APSS watchdog-stop di shim

**Hasil HP terbaru:** 0086 berhasil mount `md0`, menyelesaikan BSD init, menjalankan
static **PID 1**, dan mencetak `still alive` sampai heartbeat=4, lalu reboot.
[Bukti log](docs/evidence/0086-pid1-phone-result.txt). Baseline transisi kernel ke
userspace sudah terbukti; stabilitas terhadap reset belum. Ini belum Apple launchd.

Kernel, timer/SGI, RAM-disk dan RTC sudah melewati milestone sebelumnya. Prioritas
sekarang menguji watchdog yang diwariskan bootloader; tidak perlu mengulang build
kernel atau mengganti userdata. Reset reason belum didapat, sehingga watchdog APSS
masih hipotesis yang diuji, bukan penyebab yang sudah dipastikan.

**Uji [timelm-0086-rd-c1-wdtstop.img](https://pixeldrain.com/u/acwZLzob):**

```text
image SHA256 ca0b941ef2e8535550e10595e78a2fb8dbdc170ae6948ea7fef1248153bff71e
trial         0086-rd-wdtstop-r39974714520
kernel        0086, identik dengan image sebelumnya
```

```bash
fastboot boot timelm-0086-rd-c1-wdtstop.img
```

Rekam layar shim awal yang ditahan sekitar dua detik. Cari `WDT EN before=...
after=...`, `WDT status=... bark=...`, `WDT BITE`, dan salah satu:

- `APSS stop confirmed`: bit enable aktif lalu readback menjadi mati.
- `APSS already disabled`: watchdog ini sudah mati saat shim memeriksanya.
- `STOP NOT CONFIRMED`: register tidak memberi hasil yang dapat dikonfirmasi.

Lalu biarkan static PID 1 berjalan **minimal 2–5 menit**. Jika bertahan jauh
melewati durasi reset sebelumnya setelah stop dikonfirmasi, lanjutkan validasi
stabilitas, lalu siapkan UFS quiet dengan shim yang sama. Jika watchdog sudah mati
atau reset tetap terjadi, kumpulkan reset reason dan periksa PMIC/firmware/TZ
watchdog atau jalur exception. Jangan menganggap semua watchdog sudah mati hanya
karena APSS EN=0.

Source Linux vendor LG `drivers/soc/qcom/watchdog_v2.c` dan mainline
`drivers/watchdog/qcom-wdt.c` sama-sama memverifikasi base `0x17c10000` dan layout
KPSS: RESET +0x04, ENABLE +0x08, STATUS +0x0c, BARK +0x10, BITE +0x14. Prosedur stop:
write 0 ke ENABLE, barrier, readback. Implementasi baru hanya melakukan ini ketika
boot-arg **`timelm_wdt=stop`** ada dan bit enable aktif. Tidak mengubah PMIC, secure
world, timeout atau reset register. Image biasa tanpa flag tidak mengakses watchdog.
[Audit sumber](docs/evidence/watchdog-source-audit.json).

Kode shim: `shim/watchdog.h` dan `shim/loader.c`, commit `90d21f9`. 13 regression
test lulus, termasuk gate flag dan pemeriksaan hanya register ENABLE yang berubah.
Shim ARM64 dibuild lokal paralel `JOBS=56`; kernel CI tidak dibuild ulang. Perbandingan
byte membuktikan kernel/ADT/static init/DTB identik dengan 0086 sebelumnya; yang
berubah shim dan flag/trial ID. Upload dengan `pd upload`, checksum cocok.
[Manifest](docs/evidence/0086-wdtstop-build.json). **Varian wdtstop belum diuji di HP.**

## Riwayat 0086: RAM-disk quiet, RTC wait dilewati

[Download timelm-0086-rd-c1.img](https://pixeldrain.com/u/ejaXM7dn).
[CI 39974714520 sukses](https://github.com/rofikkerneldev/ios_timelm/actions/runs/39974714520),
commit kernel `beaed0f90ed9fd286ee6ccadb1741dbde6d2b99f`.

```text
image SHA256 322ccbde46e8b2569aca584a397f51d00c896afe9fd3563a139a125742866f81
kernel SHA256 aa2a737c5b79f2b5102d47cac5bc7f99faf3a9008d314bfcef1066be862da9a8
trial         0086-rd-r39974714520
```

```bash
fastboot boot timelm-0086-rd-c1.img
```

Satu CPU, timer 27, `startup_debug=0`, root RAM-disk; userdata tetap tidak perlu
diflash ulang. [Manifest](docs/evidence/0086-build.json). File lokal:
`shim/out/timelm-0086-rd-c1.img`; kernel aktif `xnu/out/kernel.development.sweet`
sekarang adalah **0086**. Source rekonstruksi: `$HOME/work/timelm-0086/verify`.
Backup 0085: `$HOME/work/timelm-0086/kernel-before0086.sweet`.

86 patch apply, 12 regression test, kompilasi lokal translation unit yang berubah,
build XNU macOS dan tes SGI setelah build lulus. Seluruh 10 segmen XNU dalam boot
image, ADT/DTB, commit dan patch digest serta checksum upload telah diverifikasi.
**Update hasil HP:** 0086 sudah mencapai static PID 1, tetapi reboot sesudah
heartbeat=4. Lihat bagian teratas untuk varian watchdog-stop berikutnya.

Marker IRQ tetap bertuliskan `TIMELM IRQ FIX 0085` karena perbaikan tersebut
diwariskan. Bedakan image baru memakai **trial 0086** dan marker `TIMELM RTC 0086`.
Target berikutnya: melewati `IOKitInitializeTime`, mencapai static PID 1, lalu
melihat apakah sistem tetap hidup melampaui waktu reset sebelumnya. Jika milestone
maju tetapi reset tetap periodik, lanjutkan investigasi reset reason/watchdog.
DTB memiliki `/soc@0/watchdog@17c10000`, compatible `qcom,apss-wdt-sm8250` /
`qcom,kpss-wdt`, reg `0x17c10000+0x1000`. Ini petunjuk lokasi, bukan izin untuk
menulis offset yang belum divalidasi terhadap source driver SM8250.

## UPDATE TERBARU: quiet membuktikan timer/SGI bekerja, reboot pada penantian RTC

User telah menguji `trial=0085-rd-quiet-r39968689712` dan mengonfirmasi
**reboot setelah heartbeat=4**. [Bukti log](docs/evidence/0085-quiet-phone-result.txt).
SGI1 CPU0 diterima, timer meningkat dari 41 ke 1157, dan empat heartbeat berjalan.
BSD terakhir mencetak `calling IOKitInitializeTime`; belum terlihat return, mount
root atau PID 1. Prioritas berpindah dari perbaikan interrupt ke penantian RTC/reset.

`IOKitInitializeTime()` menunggu resource `IORTC` maksimal 30 detik, sedangkan
port ini belum menyediakan driver tersebut. Dugaan watchdog firmware konsisten
dengan reset pada durasi tetap, tetapi **belum dibuktikan oleh reset reason**.
Pesan IOWatchdog stub dan boot-arg `wdt=-1` tidak membuktikan watchdog Qualcomm mati.

Patch 0086 (`0086-timelm-skip-unavailable-rtc-service-wait.patch`) melewati
penantian IORTC hanya pada konfigurasi SWEET/timelm. Tetap jalankan
`clock_initialize_calendar()` dengan fallback platform (waktu awal nol). Timer
monotonik dan heartbeat tidak diubah; watchdog hardware juga belum diubah.
Ini menghindari menunggu layanan yang tidak ada, bukan bukti reset sudah teratasi.

Build berikutnya cukup **satu image RAM-disk quiet cpus=1**. Marker yang dicari:

```text
TIMELM RTC 0086: no IORTC driver, skipping 30s service wait
TIMELM RTC 0086: calendar initialized with platform fallback
bsd_init: returned from IOKitInitializeTime
*** SWEET userspace: init running as PID 1 ***
```

Jika setelah 0086 tetap reboot pada durasi yang sama tetapi milestone maju,
investigasi watchdog/reset reason harus diprioritaskan. Jangan mengubah timer/SGI
yang sudah terbukti bekerja, dan jangan menganggap volume iOS penyebab reset
karena trial ini masih menggunakan RAM-disk. UFS tetap menunggu baseline PID 1.

## Riwayat: reboot dengan verbose startup sebelum image quiet

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

Tambahan bukti dari user (log boot sebelumnya):

```text
SWEET CPU: cpu=1 self-SGI1 mpidr=0x100 value=0x10011
SWEET CPU: cpu=1 entered initCPU mpidr=0x100 EL1 IRQs=0
```

`0x10011` memiliki INTID=0, Aff1=1, TargetList=0x11. Ini konsisten dengan
regresi encoding 0083; SGI1 untuk MPIDR 0x100 seharusnya `0x01010001`
(INTID=1, Aff1=1, TargetList=1), yang telah diperbaiki 0085. Jangan mengganti
kembali encoding baru berdasarkan log lama ini. `IRQs=0` dalam `initCPU`
sekunder masih sesuai jalur startup yang meng-unmask interrupt setelah kembali;
perlu bukti interrupt benar-benar diterima sesudahnya.

Potongan log juga memuat registrasi CPU0..CPU6. Quiet adalah `cpus=1` dan tidak
menjalankan startup CPU1; potongan lama ini harus dibedakan dari hasil trial quiet.
Tidak ada pesan penyebab panic/backtrace pada potongan yang diberikan. Pesan
`gPanicBase is still not initialized` melaporkan area panic-log belum tersedia,
bukan identifikasi penyebab exception. Ambil hasil trial quiet dan marker ID-nya
sebelum menentukan perubahan kernel berikutnya.

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
