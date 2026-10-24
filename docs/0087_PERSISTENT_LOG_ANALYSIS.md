# 0087-GUI-log: daemon grafis dan swap terbukti; observasi berhenti pada flush 5

2026-10-23. User mengonfirmasi tes image `GnxdmsDC`, melihat logo/teks “caches” dan
garis merah, lalu kembali ke recovery. Pada 2026-10-24 user mengoreksi perkiraan
durasi menjadi mungkin sekitar tiga menit (sebelumnya lima), tanpa pengukuran. Agent mengambil
ring console langsung dari userdata melalui forward ADB; ini **bukan transkripsi foto**.

- Trial di dalam ring: `0087-gui-log-r39984162472`.
- Header `SWEETLOG`, version 1, ring 4194304 byte, total 47097 byte, flush sequence 5.
- File tail 4198400 byte, SHA256
  `46b5d95fb957438375a9a87718485549a90c56e058c3b2e5a586cb7af6c58043`.
- Tidak wrap; byte nonzero terakhir tepat di batas committed total, tidak ada
  suffix log tambahan di belakang header snapshot yang bisa dipulihkan.
- [Console decoded](evidence/0087-gui-log-console.txt),
  [metadata dan temuan](evidence/0087-gui-log-pull.json).
  Tail asli: `$HOME/work/timelm-0087-gui-log-result/tail.bin`.

## Yang berubah dari kesimpulan transkripsi sebelumnya

**IOAcceleratorES compatibility service terpublikasi; SpringBoard dan backboardd
masing-masing dieksekusi sekali; backboardd membuat surface dan mengirim swap.**
Jadi tidak lagi tepat memperlakukan “daemon grafis belum start” sebagai temuan
utama. Jalur iOS sampai kernel display sudah aktif setidaknya pada awal rendering.
Ini masih belum membuktikan lock screen/home screen siap atau setiap copy selesai.

| Bukti | Lokasi pada console decoded |
|---|---|
| AppleCLCD fisik 1080×2460, stride 4320, canvas 1125×2436 | Baris 66 |
| Marker IOAcceleratorES published (no GPU) | 67 |
| Userdata LUN0, first block `0x67a628`, 32768 MiB RW | 107 |
| Logger tail absolute block `0xe7a227` | 112 |
| Cache sent to launchd successfully | 465 |
| exec SpringBoard | 469 |
| exec backboardd | 551 |
| exec lsd / com.apple.datamigrator | 592 / 611 |
| Surfaces 2 dan 3, 1125×2436 BGRA, stride 4608, size 11239424 | 720 / 733 |
| Swap 2, 3, 4, 5, 6 menggunakan surfaces 2/3 | 732, 734, 739, 744, 753 |
| Early boot complete. Continuing system boot | 776 dan 777 |
| Heartbeat terakhir 13, timer 115978, SGI1=1 | 783 |

Nomor baris merujuk salinan committed yang hashnya dicatat pada JSON. Byte stream
memiliki beberapa printk/stdout yang interleave; jangan memaksakan setiap baris
sebagai event atomik atau waktu dinding presisi.

## Batas paling penting: durasi liveness belum terukur

Heartbeat 1..13 tercapture. Swap 6 berada sesudah heartbeat 11, dan heartbeat 12/13
serta eksekusi daemon berikutnya masih berjalan setelah swap tersebut. Tidak ada
crash SpringBoard/backboardd atau laporan kernel panic dalam snapshot ini.

Namun header hanya sequence 5 dan log berakhir pada `exec calaccessd`. Ini
**tidak membuktikan kernel hidup selama seluruh durasi tunggu yang diperkirakan** dan juga belum
membuktikan kernel berhenti pada heartbeat 13. Kemungkinannya perlu dibedakan:

1. Worker logging tertahan di mutex/UFS atau gagal write/sync kemudian keluar.
2. Output tidak lagi mencapai ring, misalnya perubahan pada pipeline console;
   thread logger sekarang melewati flush bila total console tidak berubah.
3. Scheduling/timer/kernel benar-benar berhenti, atau pekerjaan menghambat
   beberapa worker. Tanpa observer independen belum dapat dipilih salah satu.

Di `sweet_log_thread()` saat ini, error write/sync mencetak `SWEET LOG: write failed`
**kemudian thread return**. Pesan terakhir itu tidak bisa diharapkan tersimpan oleh
worker yang baru saja gagal. Karena itu, tidak adanya error UFS/logger pada tail
bukan bukti seluruh operasi setelah flush 5 berhasil. Header ini juga tidak
menyimpan counter heartbeat secara independen dari teks console.

Sumber: `bsd/dev/sweet_ufs.c:748` dan seterusnya pada source 0087. Jangan menyalahkan
`calaccessd` hanya karena namanya berada di akhir snapshot, dan jangan sekadar
menunggu lebih lama tanpa memperbaiki observasi bagian ini.

## driverkitd: SIGKILL karena limit per proses

```text
CRASH driverkitd[67] sig 9 code 0x0 sub 0x0
CRASH driverkitd reason ns 1 code 0x7: (none)
```

Namespace 1 adalah `OS_REASON_JETSAM` (`bsd/sys/reason.h:88`), code 7 adalah
`JETSAM_REASON_MEMORY_PERPROCESSLIMIT` (`bsd/sys/kern_memorystatus.h:290`).
Ini penghentian SIGKILL oleh batas memori proses, bukan bukti fault instruksi GPU
atau kernel panic. Snapshot masih mencatat ReportCrash, heartbeat dan swap setelah
event itu. Tidak ada bukti kausal bahwa driverkitd menghentikan UI. Audit limit/RSS
proses itu bila diperlukan; jangan mematikan jetsam atau menaikkan limit global.

Query direktori crash report live tambahan tidak selesai: koneksi ADB kemudian
timeout, termasuk `get-state`, `shell id` dan read header, masing-masing diberi
batas 12 detik. Subprocess read yang tersangkut dihentikan; tidak ada reset server,
mount atau write ke phone. Ini bukan bukti direktori kosong atau storage rusak.
Tail utama sudah berhasil diambil dan diverifikasi sebelum gangguan koneksi itu.

## Apakah garis merah berasal dari shim?

Ada dasar source untuk dugaan user: `shim/shim.c:379` memanggil `con_clear(RED)`
sebelum `loader_boot()`, `RED=0xffff0000` di `shim/console.h`, dan `con_clear()`
menulis seluruh framebuffer. Setelah jump, shim tidak terus menggambar logo iOS.
Deskripsi Gold hand-off/SPEED dan delapan detik Topaz adalah alur boot Topaz;
bukan bukti bahwa LG sedang tertahan di tahap shim yang sama.

Pada present timelm 0087, beda tinggi canvas 2436 dengan panel 2460 memberi
`fOffY=-12`. Untuk swap full-canvas yang tercapture, row tujuan adalah 12..2447;
12 baris teratas dan terbawah tidak ditimpa oleh copy itu. Ini memungkinkan warna
atau teks lama tertinggal di margin jika belum dibersihkan. Tetapi kernel console
memiliki jalur full-screen clear yang dapat membersihkannya juga; **belum terbukti
warna garis yang dilihat benar-benar berasal dari shim** tanpa pengukuran frame.

Perbaikan kosmetik margin dapat dilakukan terpisah setelah liveness jelas:
bersihkan area di luar viewport dengan bounds/format benar, tanpa mengubah posisi
canvas. Hilangnya garis tidak akan membuktikan penyebab logo berhenti sudah selesai.

## Roadmap 0088 untuk OpenCode

**Update layout 2026-10-24:** iOS dipindah ke partisi `ios`, ADB sedang tidak
disambungkan. Pemilihan root harus diperbaiki lebih dahulu; lihat
[handoff terbaru](../OPENCODE_NEXT.md). Audit tail userdata lama bersifat historis
dan tidak boleh dipakai untuk mengaktifkan logging pada layout baru.

Langkah berikutnya adalah **diagnostik yang tidak bergantung hanya pada teks
console atau worker UFS yang sedang diaudit**. Tidak ada kernel baru dibuild pada
analisis hasil tes ini.

1. Tambahkan counter heartbeat atomik yang dinaikkan sebelum `printf`, waktu
   absolute dan timer IRQ; counter frame submitted/present accepted/rejected dan
   copy completed, dengan alasan penolakan bounded. Swap log lama dicetak sebelum
   copy, sehingga jangan menganggapnya counter completed.
2. Tambahkan state logger/UFS yang dapat diamati: last successful sequence/time,
   wait-lock/command/sync/error state, last errno dan command. Jangan printf dari
   IRQ atau menambah lock observer yang bergantung pada lock yang sedang dicari.
3. Header diagnostik dapat diperluas dengan field tambahan yang versioned tanpa
   merusak decoder lama. Tetap tulis header/liveness setiap interval walau total
   console tidak berubah. Itu membedakan console senyap dari worker yang berhenti.
   Header saja belum cukup bila storage tidak bisa ditulis: sediakan status kecil
   di framebuffer yang tetap terbaca sesudah present, opt-in pada profil diag,
   dari observer yang tidak memegang mutex UFS/IOWorkLoop display.
4. Tes satu CPU dengan kernel/profile yang sama: bila heartbeat observer lanjut
   tetapi flush berhenti, fokus logger/UFS/console; bila heartbeat/flush lanjut
   tetapi frame tidak maju, fokus IPC/renderer/LaunchServices/migrasi dan lifecycle
   IOSurface. Bila copy selesai tetapi gambar salah, audit crop/format/lifetime.
   Startup `lsd` saja belum membuktikan LaunchServices sedang membangun database.
5. Setelah itu, probe HFS DATA_PROTECT_FLAGS yang ditemukan pada dirs_cleaner;
   margin hitam merupakan perubahan terpisah. Pertahankan watchdog-stop, timer 27,
   SGI1 fix, UFS-RW dan geometry tail yang sudah diverifikasi. SMP/GPU ditunda.

Build 0088 hanya setelah patch instrumentasi siap dan diverifikasi. Kernel via
CI macOS, shim lokal `JOBS=56`, hash/manifest unik dan upload `pd upload`. Gunakan
0087-GUI-log sebagai fallback yang sudah berhasil merekam daemon/frame awal.
