# RAM2GiB: tes ulang5menit mencapai HB531/flush53

2026-10-24. User sudah mengulang tes5menit dan kembali ke ADB recovery.
Raw tail baru dibaca read-only dari `ios`/sda31, disimpan terpisah dari tes pertama.
[Metadata](evidence/0090-ram2g-5min-phone-pull.json),
[console](evidence/0090-ram2g-5min-console.txt).
Trial tetap `0090-ios-nostatus-ram2g-r40078086391`, draw0 terverifikasi;
hash raw berbeda dari capture pertama. Snapshot ini berasal dari boot baru.

| Snapshot akhir | Lama5,75GiB nostatus | RAM2GiB pertama | RAM2GiB ulang5menit |
|---|---:|---:|---:|
| HB | 62 | 152 | **531** |
| Flush header | 6 | 15 | **53** |
| IRQ full-Q6 | 110988 | 288030 | 209134 |
| Submitted / presented / copied / rejected | 6/5/5/0 | 6/4/4/0 | **6/5/5/0** |
| UFS selesai / diterbitkan | 12229/12229 | 40326/40326 | **22323/22323** |
| UFS error / waiter / fase | 0/0/0 | 0/0/0 | **0/0/0** |
| Raw fault/panic event | 0 | 0 | **0** |

Heartbeat/thread, IRQ dan persistent logger melampaui titik lama dengan jelas.
**Jangan menyatakan freeze pada HB531:** itu snapshot terakhir sebelum user
mengakhiri tes. Jumlah IRQ/UFS antarboot dipengaruhi workload dan idle; nilai
lebih kecil dari tes pertama bukan counter mundur. D88 timer209135 versus
I89/full209134 juga bukan bukti IRQ hilang: field dibaca pada waktu berbeda.

Runtime kembali melaporkan128190 free +2882 wired halaman16KiB, sesuai2GiB.
PC IRQ `0xfffffe0007494258` sama seperti tes pertama, `machine_idle+0xfc`
pada kernel0090: konteks idle yang diinterupsi, bukan fault. Q6 tercapai pada
snapshot. Tidak ada raw panic, timeout UFS, atau crash SpringBoard/backboardd
yang terekam. Driverkitd sekali lagi SIGKILL ns1/code7; boot berlanjut.

## Implikasi untuk GUI

`exec SpringBoard` dan `exec backboardd` masing-masing satu. Ada surface2/3 dan
swap2..6; hanya5 present/copy yang selesai, reject0. Ini membuktikan beberapa
frame melewati jalur copy, belum membuktikan UI interaktif atau frame kontinu.
Counter akhir tidak merekam timestamp setiap swap; jangan menentukan detik frame
berhenti hanya dari posisi baris dalam log.

Console berakhir dengan banyak peluncuran `bluetoothd` dan `fairplayd.H2`
(total48 dan50 exec). Aktivitas relaunch menunjukkan userspace masih bekerja,
tetapi penyebab exit dan hubungannya dengan GUI belum diketahui. Jangan
menonaktifkan daemon tersebut sebagai fix tanpa korelasi/dependency yang jelas.
Status layar akhir masih menunggu jawaban user; jangan mengasumsikan logo atau UI.

## Keputusan dan roadmap

1. Pertahankan **window2GiB[4,6GiB)** sebagai fallback aktif. Dua capture sekarang
   mendukung perbaikan liveness setelah menghindari gap6–8GiB. Peta recovery dan
   mainline konsisten, user mengonfirmasi upgrade fisik12GB. Root RW/timing dan
   kapasitas tetap confounder; atribusi penyebab tunggal belum selesai.
2. Penantian ulang yang sama sudah memberi jawaban liveness. Jika user melaporkan
   masih logo/hitam, langkah berikutnya adalah observasi SpringBoard/backboardd,
   IPC dan renderer, bukan meminta tes tunggu identik lagi. Jika UI muncul,
   catat milestone dan fokus validasi visual/stabilitas sebelum touch/SMP/GPU.
3. Untuk diagnostik GUI, audit sampler lama dahulu: jangan membaca stack user yang
   dapat fault sambil menahan task_lock. Rancang snapshot bounded dengan referensi
   thread yang aman dan interval terbatas, serta timestamp last-submit/last-copy,
   agar dapat membedakan GUI menunggu IPC dari tidak ada frame baru. Sampel user
   harus disimbolkan memakai proses/slide dan shared cache20H392 yang tepat.
4. Jika perlu profil status2GiB, repack kernel yang sama dengan hanya draw/trial
   berubah. Profil itu belum dibuat; status drawing sendiri tidak diperlukan
   untuk membuktikan kernel hidup pada hasil ini. Hindari build GPU/cache/clock
   atau perubahan UFS sebelum bukti GUI tersedia.
5. Implementasikan guard packaging RAM bank/hole/reserved dan payload/ADT
   consistency. Default5,75GiB lama yang melintasi gap harus diblokir/diganti;
   sampai guard tersedia, gunakan ADT2GiB eksplisit. Ini pekerjaan host yang
   dapat dilanjutkan tanpa mengubah rootfs perangkat.

Image masih [216CAPu5](https://pixeldrain.com/u/216CAPu5), SHA256
`8012dcdaabd349f40c9d07b70831f8afbb5f8f2b33d4a1751b59c6663d7e69f6`.
Tidak ada image baru dibuild, mount/fsck/flash/reboot atau write partisi oleh
agent pada pengambilan log ini. Handoff utama: [OPENCODE_NEXT.md](../OPENCODE_NEXT.md).
