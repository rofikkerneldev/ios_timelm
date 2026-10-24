# Hasil recovery 0089: HB81 tersimpan, HB84 dilaporkan di layar

2026-10-24. ADB recovery `127.0.0.1:15037` berhasil membaca tail GPT `ios`
secara read-only, 4198400 byte. [Console](evidence/0089-console.txt),
[metadata dan symbolication](evidence/0089-phone-pull.json).
Trial terverifikasi **0089-ios-irqdiag-r40074243259**; ini hasil image 0089.

| Data snapshot terakhir | Nilai |
|---|---|
| SWEETLOG / jumlah console | Flush 8 / 33375 byte |
| HB / T | 81 / 119904 |
| S / P / C / R | 4 / 3 / 3 / 0 |
| Logger F / L | 3 (pembuatan header, normal) / 7 (sukses sebelumnya) |
| UFS completed / issued : phase | 12809 / 12809 : 0 |
| UFS W / OP / E | 0 / 28 hex (read) / 0 |
| Timer IRQ masuk / handler selesai | 120918 / 120918 |
| IRQ phase | 2, sesudah handler timer/EOI+ISB, sebelum epilogue umum |
| Interrupted PC / CPSR | 0xfffffe0007399e00 / 0x40400204, kernel EL1t |

User melaporkan HB=84, OP=28, tulisan `SK[0] __nexus_register
rapportd(82): nxprov_create:`, serta animasi Apple terlihat sedikit/terpotong
sebentar selama proses. Nilai I89 terakhir, perubahannya setelah HB84, dan lama
penantian setelah angka itu belum diberikan. Jangan menyamakan heartbeat count
dengan pengukuran detik sejak logo.

## Apa yang dibuktikan

Timer observer IRQ 0089 aktif dan mampu kembali sampai fase2 pada snapshot
terakhir. Counter copy membuktikan setidaknya tiga present menyelesaikan copy
layer; R=0 pada snapshot. UFS tidak menunjukkan error, waiter atau command
outstanding pada saat snapshot. Ini bukan bukti seluruh filesystem/grafis sehat
atau kondisi yang sama bertahan setelah HB84.

PC kernel disymbolicate dengan kernel **yang sama**, SHA256
`fdecccd5d0c5f5570a07e7167c0f2b038ad8ec200432ea636cfd5d4b3a1a4d49`,
CI 40074243259. Payload/shim mempertahankan linked VM addresses. PC cocok dengan
`zalloc_ext + 0x2c`, instruksi `cmp w8, #16` dekat entry fungsi allocator.
Ini saved PC yang diinterupsi timer, bukan fault address, panic PC atau bukti
allocator hang. Sampel tunggal belum memberi call stack, durasi atau pemilik lock.

Console mengonfirmasi exec SpringBoard dan early boot complete. Tidak ada
record `CRASH ...` atau laporan kernel panic yang tercapture. `exec DumpPanic`
pada akhir snapshot adalah peluncuran daemon; bukan dengan sendirinya panic.
Sebagian event IOKit/exec/swap tidak muncul meskipun counter copy nonzero;
ketiadaan baris tidak membuktikan proses/render tidak pernah berjalan.

Baris rapportd yang disebut user tidak ada pada committed snapshot. Bisa saja
muncul setelah flush8; ia belum mengidentifikasi instruksi penyebab stall.
`OP=28` adalah opcode read terakhir, bukan kode error. Bytes di bagian blok
terakhir sesudah committed total semuanya nol; tidak ada suffix log baru di sana.

## Langkah berikutnya

1. Jika ada catatan/foto terakhir, ambil **baris I89**: I/O/H/PC/K-U/F, dan apakah
   I/O masih berubah sesudah HB84. Sertakan L/F/W/U/OP/E serta durasi penantian.
2. Jika data itu tidak tersedia, gunakan **image 0089 yang sama** dan rekam
   ketiga baris dua kali berselang 30 s setelah HB tampak berhenti. Tidak ada
   dasar build 0090 atau mengubah root/driver hanya dari snapshot ini.
3. I/O berubah tetapi H/HB diam: fokus timeout/wakeup/thread scheduling/lock;
   simpan PC berulang lalu simbolkan dengan kernel yang tepat. Jika H dari I89
   berubah tetapi D88 lama, periksa thread draw/scanout. Jika seluruh layar diam,
   bandingkan waktu/progres header sesudahnya; PC tunggal ini tidak cukup untuk
   membedakan IRQ masked/global stall/clock/scanout.
4. Jika HB/L terus bergerak tetapi GUI tidak muncul, baru kumpulkan sampel
   SpringBoard/backboardd dan dependency IPC/render. Foto animasi terpotong
   perlu dicocokkan dengan geometry/pixel source; jangan menyimpulkan GPU wajib.

[Profil, cara pull dan tabel keputusan lengkap](0089_IRQ_DIAGNOSTIC_TRIAL.md).
Belum ada hasil temporal dua titik I89 atau perbaikan penyebab GUI pada checkpoint ini.
