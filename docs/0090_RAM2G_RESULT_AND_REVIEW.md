# Hasil 0090 RAM2GiB dan review roadmap

2026-10-24. **Update: tes ulang5menit sudah mencapaiHB531/flush53.**
[Hasil terbaru dan roadmap](0090_RAM2G_5MIN_RESULT.md) menggantikan langkah
ulang5menit pada dokumen awal ini.

Trial `0090-ios-nostatus-ram2g-r40078086391` sudah diuji;
raw tail diambil dari ADB **recovery**, read-only pada `ios`/sda31.
[Metadata](evidence/0090-ram2g-phone-pull.json),
[console](evidence/0090-ram2g-console.txt),
[audit RAM recovery](evidence/0090-recovery-ram-audit.json).

**User menunggu sekitar satu menit**, titik awal pengukuran belum disebutkan.
Jangan menyatakan membeku pada HB152. Status UI akhir dan apakah transisi recovery
manual belum dinyatakan eksplisit. HB adalah jumlah iterasi thread dengan sleep,
bukan stopwatch waktu menunggu logo dari user.

## Perbandingan bukti

| Snapshot tersimpan | 0090 nostatus lama | 0090 nostatus RAM2GiB |
|---|---:|---:|
| Heartbeat | 62 | **152** |
| Flush header | 6 | **15** |
| IRQ sampai tahap Q6 | 110988 | **288030** |
| Submitted / presented / copied / rejected | 6 / 5 / 5 / 0 | 6 / 4 / 4 / 0 |
| UFS selesai / diterbitkan | 12229 / 12229 | **40326 / 40326** |
| UFS error / waiter / fase | 0 / 0 / 0 | 0 / 0 / 0 |
| Raw panic/fault event | 0 | 0 |
| Status drawing | off | off |

HB/IRQ/UFS/logger mencapai snapshot jauh melewati hasil sebelumnya. Ini bukti
kemajuan liveness, **belum bukti stabilitas tanpa batas atau GUI interaktif**.
Empat copy selesai tidak mengukur FPS dan tidak membuktikan frame berikutnya tiba.
Tidak ada bukti bahwa sistem berhenti tepat setelah snapshot terakhir.

Kernel benar-benar menerima kapasitas2GiB: `vm_page_bootstrap` mencatat
128190 free + 2882 wired =131072 halaman16KiB =2147483648 byte. Baseline lama
372958+3874 =376832 halaman =5,75GiB. Bukan sekadar perubahan nama image.

Console mencatat `exec SpringBoard`, `exec backboardd`, surface2/3 dan swap2/4/5/6,
kemudian banyak daemon lain. Driverkitd mendapat SIGKILL dengan namespace1/code7
(batas memori per proses), lalu boot berlanjut. Kejadian serupa ada sebelum RAM
diperkecil, sehingga tidak boleh langsung disebut akibat2GiB. Tidak ada laporan
crash SpringBoard/backboardd atau raw panic pada snapshot ini; kejadian setelah
flush terakhir tetap tidak tercakup.

IRQ PC `0xfffffe0007494258` pada **kernel0090 yang sama** resolve ke
`machine_idle+0xfc`, instruksi `ldp x29,x30,[sp,#48]` setelah `DAIFClr`.
Ini sampel konteks yang diinterupsi, bukan fault PC atau alasan untuk menambahkan
`jtag=1` lagi. Enter/done/full-Q6 semuanya288030. Q6 bukan bukti seluruh jalur
assembly return sudah selesai, tetapi C epilogue tercapai pada snapshot itu.

## Validasi temuan RAM GPT-6-Sol

**Arah analisis dan kontrol2GiB benar serta sesuai roadmap.** Roadmap awal memang
memisahkan liveness kernel, logging dan framebuffer sebelum memilih perubahan
GPU/filesystem. Memeriksa RAM lebih dahulu masuk akal ketika ditemukan rentang
fisik yang tidak sesuai peta live.

User kini mengonfirmasi RAM fisik pernah di-upgrade menjadi **12GB**, dtbo dihapus,
dan DTB berada langsung di kernel, bukan dipakai dari partisi DTB terpisah.
Itu menjelaskan laporan kapasitas live. Pernyataan layout ini berasal dari user;
tidak ada penghapusan atau modifikasi partisi oleh agent pada pemeriksaan ini.

Recovery kernel4.19 dan Android mainline7.3 mendeklarasikan bank yang sama:

| Base | End eksklusif |
|---|---|
| 0x80000000 | 0xb9900000 |
| 0xc0000000 | 0x180000000 |
| 0x200000000 | 0x400000000 |

Keduanya mempunyai gap **[6GiB,8GiB)**. `/proc/iomem` recovery juga mengonfirmasi
window kontrol **[4GiB,6GiB)** berada di System RAM, tanpa overlap reserved-memory
atau FDT memreserve. Ini validasi silang dua kernel, bukan pengujian elektrik DDR.
DTBO dihapus tidak menghilangkan pentingnya peta RAM pada FDT runtime.

Default XNU lama **[4GiB,9,75GiB)** melintasi gap tersebut. Kapasitas fisik12GB
tidak berarti semua alamat dari4GiB sampai9,75GiB tersedia secara kontigu.
Jangan memakai default lama sebagai baseline aman. Static DTB size0 adalah
placeholder; checker MMIO/CPU/timer yang PASS sebelumnya tidak memvalidasi DRAM.

Batas kesimpulan yang perlu dijaga:

- Kemajuan satu trial memperkuat keputusan menghindari gap; belum membuktikan
  alokasi ke gap sebagai penyebab tunggal stall lama. Pembatasan kapasitas juga
  mengubah penempatan alokasi, tekanan memori dan timing.
- Payload kontrol identik kecuali ukuran RAM/ADT dan trial, tetapi filesystem
  root RW berubah antarboot (cache/migrasi/database). Ini bukan A/B seluruh
  keadaan perangkat yang identik. Jangan reflash root hanya untuk menyamakan tes.
- Nostatus hanya menghilangkan status drawing; copy GUI/fade dan mapping default
  surface tetap ada. Hasilnya tidak membebaskan semua jalur framebuffer.
- No-event pada header terakhir bukan bukti tidak mungkin ada panic sesudahnya.
  Pesan terakhir, `machine_idle`, rapportd atau sampel crypto bukan diagnosis.

## Roadmap berikutnya untuk OpenCode

1. **Ulang image2GiB yang sama, tanpa rebuild:** tunggu5menit setelah logo pertama
   (catat waktu), catat UI/logo/reboot, lalu user kembali recovery. Jangan boot
   default lama yang melintasi gap hanya untuk mengejar A/B; bukti baseline lama
   sudah disimpan. Pull log ke file unik sebelum tes berikutnya.
2. Verifikasi trial ram2g dan bandingkan HB/flush/IRQ/UFS/copy. Jika semuanya maju
   sesuai tes lebih lama tetapi tetap logo, fokus berikutnya pada proses GUI,
   IPC dan present. Jika snapshot berulang berhenti dekat nilai yang sama meski
   durasi lebih panjang, lanjutkan roadmap observer/lock/IRQ; jangan simpulkan
   hanya dari satu akhir file. Jika panic muncul, gunakan raw event dan simbol
   kernel tepat yang dibuild.
3. Pertahankan **ADT2GiB eksplisit** untuk tes berikutnya. Tambahkan validasi
   cakupan RAM bank, hole, reserved regions dan payload/ADT consistency pada
   packaging; static memory size0 harus dilaporkan unverified, bukan PASS RAM.
   Default rentang lama harus diganti dengan window konservatif setelah kontrol
   stabil, atau diblokir sampai ada RAM audit yang valid. Guard belum diimplementasikan.
4. Jika liveness stabil, ambil sampel SpringBoard/backboardd yang aman dan bounded.
   Audit sampler lama (task_lock/faulting stack reads) dahulu; jangan langsung
   aktifkan sampler intrusif. Korelasikan IPC/renderer dengan S/P/C dan crash log,
   kemudian uji copy/pixel/cache/lifetime sesuai bukti. GPU bukan prasyarat jalur
   software yang sedang diuji.
5. Dukungan bank RAM atas/multibank, SMP dan GPU ditunda. Shim saat ini memetakan
   di bawah8GiB; pindah base ke8GiB perlu audit loader/pmap, bukan repack sederhana.

Image tetap [216CAPu5](https://pixeldrain.com/u/216CAPu5):
`timelm-0090-ios-rw-c1-wdtstop-nostatus-ram2g.img`,
SHA256 `8012dcdaabd349f40c9d07b70831f8afbb5f8f2b33d4a1751b59c6663d7e69f6`.
Tidak ada kernel/image baru dibuild pada review ini. Tidak ada mount, fsck,
flash, reboot perangkat atau perubahan isi partisi yang dilakukan oleh agent.
