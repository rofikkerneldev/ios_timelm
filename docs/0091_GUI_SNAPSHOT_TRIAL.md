# 0091: snapshot GUI bounded dan waktu frame

Checkpoint implementasi2026-10-24. Hasil2GiB sebelumnya mencapaiHB531/flush53;
[bukti](0090_RAM2G_5MIN_RESULT.md). Kernel tetap satuCPU, rootiosRW, watchdog-stop,
sampler profil lama off. Status UI akhir masih belum dilaporkan; tujuan0091
adalah mengamati proses GUI tanpa mengulang sampler stack lama yang berisiko.

## Perubahan

Patch `0091-timelm-bounded-gui-snapshots.patch` mengganti sampler lama:

- Maksimal dua task per putaran; callback proc mengambil task reference lalu
  mengembalikan proc reference sebelum sampling. PROC_NOWAITTRANS menghindari
  menunggu exec transition daemon lain saat enumerasi.
- Maksimal32 thread pertama per task. Hanya pengumpulan thread references dan
  alamat Mach header dilakukan di bawah task_lock; output dan thread state API
  dilakukan setelah unlock. Setiap reference thread/task dilepas kembali.
- THREAD_BASIC_INFO dibaca sebelum ARM_THREAD_STATE64. API thread_get_state XNU
  dapat menahan/menghentikan thread sebentar; ini diagnostik opt-in yang tetap
  memengaruhi scheduling. Batas32thread/2task/6round adalah batas jumlah pekerjaan,
  bukan jaminan latensi hard timeout untuk internal kernel locks/thread_stop.
- Tidak ada pemanggilan vm_map_read_user/copyin atau pembacaan frame-pointer
  user. PC/LR/SP saja, tanpa backtrace user. SMP header mempertahankan slide shared
  cache dan Mach header untuk symbolication perproses yang tepat. G91 mencatat
  threadID, run_state, suspend count, flags dan kode hasil API. Jika get_state
  gagal/size berbeda, tidak mencetak register seolah valid.
- Default sampler sekarang off jika sweetsample tidak ada. Profil baru akan
  memilih sweetsample=SpringBoard,backboardd. Default first90s, interval60s,
  count6; opsi sweetsample_start/secs/count dibatasi30..600s dan1..10round.
- TIMELM91 pada offset640 header log: vsync count/time, submit/present/copy time,
  display power state/change time, sampler cycle/time/target count/phase.
  Ukuran104byte, versi1, tidak mengubah ABI0088/89/90. Phase1 enumerate,2/3
  sampling target pertama/kedua,4 round selesai. Nilai tiapfield bukan transaksi
  atomik lintasheader. Timestamp adalah mach_absolute_time, bukan waktu kalender.

Profil0090-ram2g tetap fallback. Semua perubahan transport UFS, scheduler, GPU,
rootfs dan peta memori kernel ditunda. Telemetry0091 aktif hanya timelm_diag=1;
status drawing tetap off pada profil baru. GUI copy tetap aktif.

## Verifikasi dan build

91patch apply bersih; compile lokal exception.c, sweet_sample.c, sweet_ufs.c,
SweetFramebuffer.cpp dengan headerbaru lulus. Native ASan/UBSan menguji fungsi
snapshot aktual dengan reference/lock mocks, task kosong, thread terminated,
unexpected state count dan cap32/truncation. Decoder menguji extensionbaru,
headerlama dan versi tidak dikenal. Regression boot/diag/IRQ/rawfault lulus.

Build CI macOS [40094642531](https://github.com/rofikkerneldev/ios_timelm/actions/runs/40094642531),
source `def5b767928e19c37d12fa4df186bb27bc8ea379`, sedang berjalan.
Packaging Linux belum selesai pada checkpoint ini.
Jangan menganggap image0091 tersedia sampai manifest/hash/upload dicatat.

## Pengujian berikutnya

Gunakan window2GiB[4,6GiB) yang sudah divalidasi; jangan kembali default5,75GiB.
Setelah image tersedia, user boot manual dan tunggu5menit setelah logo. Catat
apakah logo, hitam atau UI, lalu kembali recovery. Pull rawtail unik; verifikasi
trial0091 dan TIMELM91 sebelum membandingkan.

Jika vsync/time dan HB maju tetapi last_submit lama, periksa sampel GUI/IPC.
Jika submit baru tetapi present/copy lama, telusuri fDirty/workloop/power state.
Jika copy maju tetapi layar salah, audit pixel/crop/scanout/cache/lifetime.
Jika sampler phase tertahan dan liveness menurun, gunakan fallback0090 dan audit
jalur snapshot; jangan menjadikan profil diagnostik sebagai baseline stabil.
Sample PC pada mach_msg/workqueue sendiri tidak membuktikan deadlock; bandingkan
beberapa round dan thread/process yang sama beserta state/slide.

## Guard RAM pada packaging host

`tools/mkadt.py --mem high` kini default2GiB[4,6GiB), menggantikan5,75GiB lama.
`tools/build-boot.sh` memanggil `check-ram-window.py` sebelum membangun init/shim;
`inspect_boot.py` memeriksa kembali window dari ADT/payload dan menyimpan hash
audit di manifest. Guard memerlukan cakupan penuh live banks dan System RAM,
menolak gap, reserved-memory/memreserve, overflow dan alignment yang tidak sah.
Static DTB memory size0 tetap tidak dianggap bukti RAM. Default audit berasal
recovery perangkat12GB ini; ini bukan tabel universal semua varian LG V60.
Jika topology berubah, audit ulang dan berikan RAM_AUDIT yang baru.

Empat tes guard lokal mencakup kontrol2GiB yang valid, window lama yang melintasi
hole, bank bersebelahan, coverage Linux, reserved/memreserve dan batas end-exclusive.
Image fallback0090-ram2g juga lolos inspector baru dengan kernel0090 yang tepat.
Guard host tidak mengubah kernel yang sedang dibuild di CI. Jalur manual yang
melewati wrapper/inspector tetap tanggung jawab pembuat payload.
