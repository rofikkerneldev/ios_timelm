# 0089: pisahkan timer IRQ dari thread heartbeat

2026-10-24. Source `ac7bcf33eb2613319628ea0c83060a3d03f6cc11`.
CI [40074243259](https://github.com/rofikkerneldev/ios_timelm/actions/runs/40074243259)
**sukses**, image sudah diuji pada HP. Recovery menyimpan HB81/flush8 dengan
120918 timer IRQ masuk/selesai; user melihat HB84 dan sebagian animasi Apple.
[Hasil dan langkah berikutnya](0089_PHONE_RESULT.md): data I89 sesudah HB84 belum
tersedia, sehingga cabang IRQ-versus-thread saat layar diam belum dapat ditentukan.

## Image tes terbaru

[Download timelm-0089-ios-rw-c1-wdtstop-irqdiag.img](https://pixeldrain.com/u/DgtbxBkY),
[manifest](evidence/0089-build.json).

```text
trial  0089-ios-irqdiag-r40074243259
SHA256 10a80a42fb4713756369f06d177b5285613c4c689cba08114dabc798d961b560
kernel fdecccd5d0c5f5570a07e7167c0f2b038ad8ec200432ea636cfd5d4b3a1a4d49
```

```bash
fastboot boot timelm-0089-ios-rw-c1-wdtstop-irqdiag.img
```

Kernel berasal dari CI di atas; shim JOBS=56. Hash/ukuran upload, 10 segmen
payload/ADT/DTB, simbol IRQ dan panggilan kedua hook pada disassembly sleh_irq
sudah diverifikasi. Profil memakai root `ios` RW, cpus=1, watchdog-stop,
timelm_diag=1, timelm_irqdiag=1, heartbeat1s, logger10s, renderer5Hz, idle normal.

1. Tes sekitar tiga menit setelah status muncul. Jika HB diam, ambil foto/catat
   **ketiga baris**, lalu ulangi sesudah 30 s. Sertakan I/O/H/PC/K-U/F pada I89,
   HB/T/S/P/C/R pada D88, dan L/F/W/U/OP/E pada baris terakhir.
2. Catat jika hanya baris tertentu yang bergerak, reboot, atau UI muncul.
3. Kembali ke recovery dan sambungkan ADB. Pull dengan decoder terbaru:

```bash
SWEET_LOG_PARTITION=ios \
SWEET_ADB_BIN=/home/rofikkernel/alpha/out/host/linux-x86/bin/adb \
SWEET_ADB_HOST=127.0.0.1 SWEET_ADB_PORT=15037 \
sh tools/sweet-log-pull.sh "$HOME/work/0089-console.txt" \
  2> "$HOME/work/0089-console.meta.txt"
```

Verifikasi trial baru pada TIMELM_DIAG, simpan JSON TIMELM_IRQ dan raw `.bin`.
Tidak perlu reflash root iOS untuk tes ini.

## Hasil no-idle yang memicu perubahan

[Console](evidence/0088-noidle-console.txt),
[metadata](evidence/0088-noidle-phone-pull.json). Recovery ADB read-only memverifikasi
trial `0088-ios-noidle-r40067579578`. Header terakhir flush=7, HB=72, T=111280,
S=6/P=C=4/R=0, F=3/W=0/E=0, U=11509/11509:0. F=3 normal karena snapshot
extension dibuat saat membentuk header; log_success_seq=6 merujuk flush sebelumnya.

User melaporkan HB=76/T=127289/S=6/P=C=4, F=W=0, OP=28, U=13876, kemudian
status diam meski menunggu sekitar tiga menit. L/E/issued/fase U tidak tercatat.
Footer R ditranskripsikan 8, tetapi disk R=0 pada P=C=4 yang sama. R hanya
bertambah di dalam present dan C diperbarui setelah semua layer; perubahan R
dengan P/C tetap ini belum konsisten dengan jalur normal. Pertahankan angka user
sebagai **belum terkonfirmasi**, bukan langsung mendiagnosis delapan layer gagal.
Tidak ada frame reject fix pada 0089. Foto/hasil header berikutnya perlu diperiksa.

No-idle tidak mencegah gejala; jtag=1 bukan solusi yang terbukti. Header dan footer
memperlihatkan empat copy selesai dan UFS tidak sedang tertahan saat snapshot,
tetapi belum menunjukkan apa yang terjadi sesudah observer diam. Console tidak
memuat semua aktivitas yang dibuktikan counter (misalnya tidak ada swap lines
padahal P/C=4); jangan memakai ketiadaan baris console sebagai bukti tidak berjalan.

T pada D88 hanya disalin oleh heartbeat. Jika thread tidak berjalan, nilai T yang
terlihat berhenti walaupun timer IRQ mungkin tetap aktif. Inilah observasi yang
ditambahkan 0089, sebelum menambah GPU/SMP/patch filesystem atau sampler intensif.

## Perilaku opt-in

`timelm_diag=1 timelm_irqdiag=1` mengaktifkan telemetry timer IRQ CPU0 dan
mencadangkan **96 pixel rows** bawah panel: 32 untuk I89, 64 untuk D88 lama.
Pengecualian present/fade mencakup 96 rows. Thread heartbeat tetap hanya menulis
dua baris terbawah; IRQ mempunyai strip tersendiri, sehingga keduanya tidak
menimpa satu sama lain. Tambahan crop ini sengaja untuk profil diagnostik.

```text
I89 I=... O=... H=... PC=... K F=2
D88 HB=... T=... S=... P=... C=... R=...
L=... F=... W=... U=completed/issued:phase OP=... E=...
```

- I: timer IRQ CPU0 masuk, sesudah GIC acknowledge dan sebelum timer prologue.
- O: handler timer kembali dan EOI+ISB selesai, **sebelum entropy/common IRQ
  epilogue**. Ini bukan bukti seluruh IRQ telah kembali ke thread/userspace.
- H: salinan counter heartbeat yang dibaca langsung dari IRQ; bandingkan dengan
  HB pada baris D88.
- PC: saved PC yang sedang diinterupsi timer, ditampilkan hex tanpa `0x`; K/U
  berasal dari saved CPSR. Ini sampel konteks, bukan crash PC atau backtrace.
- F pada I89: 1 sebelum timer prologue, 2 setelah timer handler/EOI+ISB. Berbeda
  dari F logger pada baris ketiga. F=1 bisa merupakan snapshot transien normal.

Counter atomik diperbarui setiap timer IRQ yang diamati, tetapi gambar strip
dibatasi satu pasangan entry/done per detik. Kode IRQ tidak memanggil printf,
snprintf, mutex, alokasi, IOKit messaging/workloop atau UFS. Format angka memakai
buffer stack terbatas dan glyph font yang sudah ada. Peta framebuffer dipublikasikan
sekali dengan release/acquire; bila belum tersedia, tidak ada write pixel.
Penulisan hanya strip 32 rows, bukan salinan frame GUI penuh.

Draw IRQ tetap menambah pekerjaan dengan interrupt masked, sehingga dapat
mempengaruhi timing. Ini observer opt-in, bukan perbaikan scheduler. Pembatasan
frekuensi memakai mach_absolute_time yang sama dengan sistem; ia bukan clock
eksternal independen. Jika clock itu sendiri berhenti, tampilan periodik juga
dapat berhenti. Kondisi CPU/IRQ masked/scanout tidak selalu terpisah hanya dari
satu foto.

## Header dan verifikasi

SWEETLOG v1 dan extension D88 tetap utuh. Extension tambahan `TIMELMIQ` v1,
80 byte di offset 320, memuat delapan u64: entered, handler_done, entry_abs,
handler_done_abs, interrupted_pc, interrupted_cpsr, phase, draw_abs. Seluruhnya
masih di header 4096 byte; ring dan lokasi tail `ios` tidak berubah.
Decoder lokal mencetak JSON `TIMELM_IRQ` ke stderr. Ini snapshot atomik per field,
bukan transaksi seluruh state; snapshot hanya tersimpan bila logger/UFS maju.

89 patch berhasil diaplikasikan, tiga translation unit C/CPP (UFS/framebuffer/IRQ)
lolos kompilasi lokal. Lima checks D88 dan 14 boot regression checks tetap lolos.
Dua checks baru menjalankan draw/entry/done code aktual dengan ASan/UBSan untuk
bounds, padding/guards, enable/no-mapping gates, angka u64 maksimum, interval draw,
area D88 tidak tertimpa, serta ABI/decoder versi lama/baru. Barrier ARM diganti
fence native hanya pada harness host. CI menjalankan checks baru juga.

## Cara tes dan cabang roadmap

Profil image di atas menggunakan cpus=1, root ios RW, watchdog-stop, logger10s,
heartbeat1s, renderer5Hz dan idle normal seperti baseline D88. Sampler masih off.
Tes sekitar tiga menit; foto **ketiga baris** dua kali berselang 30 s, terutama
sesudah HB tampak berhenti. Lalu recovery dan pull memakai decoder lokal, simpan
`.bin` dan stderr JSON serta verifikasi trial baru.

| Hasil | Pemeriksaan berikutnya |
|---|---|
| I/O berubah, HB/H diam | Timer masih ditangani; telusuri thread heartbeat, timeout/wakeup, scheduler/starvation, lalu locks. PC K berulang perlu disymbolicate terhadap kernel 0089 yang sama. |
| I/O/H bergerak, D88 tampak lama | Periksa thread draw D88, framebuffer/scanout dan urutan update; H dari IRQ menunjukkan heartbeat masih naik. |
| I/H dan L maju, frame berhenti | Kumpulkan sampel SpringBoard/backboardd dan dependency IPC/render, dengan timing sampler yang sesuai. |
| Seluruh layar diam, header setelahnya maju | Tampilan/scanout atau draw path perlu diperiksa; seluruh kernel tidak berhenti pada waktu itu. |
| Semua observer/flush berhenti | Belum membedakan IRQ masked, global stall, clock atau scanout; lanjut instrumentation last progress/lock/CPU state dengan bukti PC/phase yang ada. Jangan langsung mengklaim GPU sebagai penyebab. |

Kernel PC memerlukan simbol kernel yang sama dan slide kernel yang sesuai,
bukan shared-cache slide. User PC menggunakan header slide proses yang tepat;
angka PC IRQ saja tidak mengidentifikasi PID/cache slide. Satu sampel tidak
menunjukkan call stack atau instruksi yang pasti menyebabkan stall.

Tidak ada perubahan transport UFS, error return, timer programming, GIC init,
CPU idle policy, GPU, SMP atau data root pada patch ini.
