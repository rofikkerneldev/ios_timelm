# Hasil 0088 dan tes pembanding CPU idle

**Update terbaru:** no-idle sudah diuji, footer kembali dilaporkan diam pada
HB=76 setelah menunggu sekitar tiga menit. Recovery memverifikasi trial noidle,
header terakhir HB=72/flush=7. [Hasil dan rancangan 0089](0089_IRQ_DIAGNOSTIC_TRIAL.md)
menjadi checkpoint terbaru; no-idle belum menyelesaikan gejala.

2026-10-24. [Raw metadata dan counter](evidence/0088-phone-pull.json),
[console](evidence/0088-console.txt). Recovery ADB read-only berhasil membaca
4198400 byte dari tail GPT `ios` / sda31. Extension memverifikasi trial
`0088-ios-diag-r40067579578`; ini bukan ring 0087 lama.

## Apa yang diamati

| Field | Header terakhir, flush 6 | Footer yang ditranskripsikan user |
|---|---:|---:|
| HB | 62 | 71 |
| T | 102823 | 118024 |
| S / P / C / R | 7 / 5 / 5 / 0 | 8 / 6 / 6 / 0 |
| L | 5 (sukses sebelum header sekarang) | Tidak terbaca |
| F | 3 (sedang menyiapkan header, normal) | 0 (idle) |
| W | 0 | 0 |
| U completed / issued : phase | 12176 / 12176 : 0 | 14899 / 14899 : 0 |
| OP / E | 2a / 0 | 28 / 0 |

Header memiliki 45390 console bytes. Footer menunjukkan observer dan I/O/frame
masih maju sesudah snapshot disk. User melihat counter berubah sebelumnya,
kemudian tidak berubah lagi sesudah foto; durasi sesudah foto tidak diukur dan
tidak ada transkripsi kedua. Logo Apple tetap, `exec spring` sempat terlihat.
Teks disebut berada sekitar tengah layar; lokasi ini belum dapat divalidasi
tanpa gambar/scanout geometry dan jangan langsung diartikan crop yang salah.

Console memastikan root `ios` RW, exec SpringBoard dan backboardd, publikasi
IOAcceleratorES, display on, surfaces 2/3 (1125x2436 BGRA, stride 4608), dan
swap sequence 2,4,5,6,7. Counter copy-completed memperkuat bahwa proses memcpy
frame memang selesai; belum membuktikan isi UI/format/scanout benar.

CRASH yang tercapture adalah driverkitd[67], SIGKILL, namespace 1 code 7
(jetsam per-process memory limit), diikuti aktivitas boot/frame berikutnya.
Symbolication dengan cache 20H392 cocok dengan hasil lama: `_read + 8`,
`__NSReadFromFileDescriptorWithProgress + 192` dan pembacaan NSData. Tidak ada
CRASH SpringBoard/backboardd atau laporan kernel panic yang tercapture.

## Interpretasi dan batas kesimpulan

- `S=8` dan `P=C=6` bukan bukti dua frame hilang/tertahan. `swap()` hanya menyimpan
  record terbaru dalam `fPending`; vsync menampilkan record terbaru pada tick
  yang dipilih. Beberapa submit dapat digabung sebelum present berikutnya.
- F=0, W=0, U selesai=issued, phase=0, E=0 tidak menunjukkan mutex/command UFS
  yang tertahan pada saat footer digambar. Itu belum menguji seluruh semantik
  filesystem/storage dan tidak mengungkap state setelah observer berhenti.
- Header HB=62 / flush=6 dan footer HB=71 dapat sesuai dengan stall sebelum
  flush berikutnya. Karena interval logger 10 s, selisih sekitar sembilan wake
  juga normal pada saat snapshot footer itu sendiri. Tanpa durasi kedua atau
  data baru, jangan menyatakan logger pasti berhenti tepat setelah flush 6.
- T pada footer **dibaca oleh thread heartbeat**, bukan counter IRQ yang dicetak
  oleh interrupt secara independen. Jika observer/thread/scanout berhenti, T yang
  terlihat juga diam walaupun IRQ mungkin masih berjalan. Ini belum membuktikan
  seluruh CPU/timer hang, dan bukan bukti masalah GPU sebagai penyebab tunggal.
- Observer 0088 menghindari printf/UFS/workloop locks. Laporan footer berhenti
  menaikkan prioritas pemeriksaan scheduler, idle/wake, interrupt, serta tampilan
  yang membeku, dibanding langsung mengasumsikan renderer userspace menunggu.

## Tes berikutnya: ubah satu kebijakan CPU idle

Source upstream yang sudah dipatch, `osfmk/arm64/cpu.c`, memiliki argumen
`jtag`. Pada `cpu_machine_idle_init()`, nilai nonzero mengatur `idle_enable=FALSE`;
`cpu_idle()` mengembalikan kontrol melalui `Idle_load_context()` sebelum jalur
idle/WFI. Ini hipotesis idle/wake untuk diuji, bukan diagnosis atau perbaikan
yang sudah terbukti. Source aktif hanya mempunyai satu pembaca boot-arg ini.

[Download timelm-0088-ios-rw-c1-wdtstop-noidle.img](https://pixeldrain.com/u/CnUC1KoY),
[manifest/perbandingan](evidence/0088-noidle-build.json).

```text
trial  0088-ios-noidle-r40067579578
SHA256 5ed52854ce812ad04f6ecf6caf51675c5ef6a7e491d9b9f8325bc14d3ea6ec48
```

```bash
fastboot boot timelm-0088-ios-rw-c1-wdtstop-noidle.img
```

Kernel CI 40067579578 sama persis, tidak membutuhkan build kernel baru. Shim
dikompilasi JOBS=56. Kernel/shim/ADT/DTB/static init dan payload di luar buffer
command line identik baseline 0088. Perubahan argumen **hanya `jtag=1` dan trial
unik**. Root tetap ios RW, cpus=1, watchdog-stop/observer/logger tetap aktif,
sampler masih off. Tidak ada perubahan GPU, SMP, touch atau layout filesystem.

Ini profil diagnostik sementara yang menonaktifkan CPU idle, sehingga penggunaan
CPU/dayanya dapat lebih tinggi. Cukup tes sekitar tiga menit setelah footer
muncul; ambil dua foto/catatan counter berselang 30 s, terutama apakah HB melampaui
71 dan terus berubah. Catat L, S/P/C/R, F/W/U/OP/E. Jika sudah berhenti, catat nilai
dan lama diam sebelum recovery; tidak perlu penantian sepuluh menit lagi.

Kembali ke recovery, sambungkan forward, gunakan pull/decoder lokal sebagaimana
[panduan 0088](0088_DIAGNOSTIC_TRIAL.md). Verifikasi trial `0088-ios-noidle-...`.

## Roadmap berdasarkan hasil pembanding

1. **No-idle bertahan lebih lama:** ulangi perbandingan baseline/no-idle untuk
   menilai pengaruh variasi boot. Jika berulang, telusuri idle entry/exit,
   SetIdlePop/ClearIdlePop dan virtual-timer/GIC wake state. Jangan menganggap
   `jtag=1` solusi produksi. Jika GUI tetap tertahan tetapi HB/L maju, baru buat
   profil sampling SpringBoard/backboardd terpisah memakai kernel yang sama.
2. **HB/footer tetap membeku:** rancang 0089 untuk memisahkan IRQ yang masih
   berjalan dari thread yang tidak dijadwalkan dan scanout yang membeku. Counter
   virtual IRQ entry/exit, saved ELR/SPSR kernel/user dengan sanitasi, idle
   entry/exit, serta fase workloop perlu diamati tanpa printf, mutex, alokasi,
   UFS atau framebuffer copy besar di IRQ. Jika menampilkan indikator dari IRQ,
   harus kecil, dibatasi frekuensi dan diuji overhead/range-nya terlebih dahulu.
3. **HB/L terus maju tetapi S/P/C diam:** kumpulkan sampel thread pengguna dan
   dependency IPC. Sampler inherited baru mulai 90 s setelah start; jika stall
   terjadi lebih awal, parameter waktu sampling harus disiapkan sebelum memakai
   profil itu. Evaluasi task_lock dan pembacaan stack faulting sebelum menambah
   intensitas sampling; jangan menjadikan sampler sumber deadlock baru.
4. **C terus naik tetapi GUI salah:** validasi isi surface, format/stride/crop,
   source lifetime dan jalur scanout/cache. Lokasi footer yang dilaporkan user
   perlu dicocokkan dengan geometry aktual. GPU tetap pekerjaan terpisah.

Kernel 0089 sudah dibuild dan diunggah, belum diuji HP; lihat checkpoint di atas.
Belum ada image sampling baru.
Simpan raw tail/console/metadata setiap trial sebelum boot berikutnya menimpanya.
