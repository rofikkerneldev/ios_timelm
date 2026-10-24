# NOSTATUS tidak memperpanjang snapshot; temuan peta RAM dan tes2GiB

2026-10-24. **Update: RAM2GiB sudah diuji, HB152/flush15; user menunggu1menit.**
[Hasil terbaru dan review roadmap](0090_RAM2G_RESULT_AND_REVIEW.md). Recovery
mengonfirmasi gapRAM6–8GiB, user mengonfirmasi upgrade fisik12GB.
Rincian sebelum tes di bawah dipertahankan sebagai riwayat.

[Log nostatus](evidence/0090-nostatus-console.txt),
[metadata](evidence/0090-nostatus-phone-pull.json),
[audit RAM live](evidence/live-ram-map-20261024.json).

## Hasil log yang sudah dipastikan

ADB sekarang berasal dari **Android mainline16/kernel7.3.0-sm8250rofikkernel_4**,
uid0, state device, bukan recovery. Root memiliki akses baca sda31/ios dengan
ukuran yang sama dengan audit. Raw tail diambil read-only, tanpa mount/write.
Trial `0090-ios-nostatus-r40078086391`, draw_enabled0 dan draw_abs0 terverifikasi.

| Snapshot | diag | nostatus |
|---|---:|---:|
| HB/flush | 62/6 | 62/6 |
| IRQ sampai Q6 | 103356 | 110988 |
| Present/copy selesai/reject | 4/4/0 | 5/5/0 |
| UFS completed/issued | 10252/10252 | 12229/12229 |
| UFS error/waiter | 0/0 | 0/0 |
| Raw panic/fault event | 0 | 0 |
| Status draw | 1 | 0 |

Status drawing bukan syarat terjadinya gap snapshot pada trial ini. Ini belum
menguji semua penulisan framebuffer: copy/fade GUI dan mapping user tetap aktif.
Waktu tes nostatus serta apakah user pindah ke Android sendiri atau reboot
otomatis masih menunggu klarifikasi. Boot-reason properties Android tidak
diterima sebagai bukti pasti reset XNU atau terjadinya wipe. Tidak ada timeout UFS
atau panic yang tercapture; snapshot lama tetap tidak meniadakan kejadian setelahnya.
PC IRQ nostatus0x1d664f220 adalah user PC tanpa slide/proses; tidak disimbolkan
dengan simbol kernel. Bytes setelah committed total dalam blok terakhir nol.

## Temuan yang mengubah prioritas: rentang DRAM

Static DTB yang dipakai shim (`dtb/boot_unpacked/dtb`) mempunyai
memory@80000000.reg = base0x80000000,size0. Itu **placeholder**, bukan bukti
rentang fisik RAM. Checker ADT/DTB selama ini memeriksa MMIO/CPU/timer/splash;
status PASS-nya tidak membuktikan rentang DRAM manual valid.

Device tree live Android mainline melaporkan bank:

| Base | End eksklusif | Ukuran |
|---|---|---|
| 0x80000000 | 0xb9900000 | 0x39900000 |
| 0xc0000000 | 0x180000000 | 3GiB |
| 0x200000000 | 0x400000000 | 8GiB |

/proc/iomem sejalan: SystemRAM0xc0000000..0x17fffffff, kemudian
0x200000000..0x3ffffffff. MemTotal melaporkan11799844KiB. Ini peta yang
dideklarasikan Android, **belum pengukuran elektrik RAM**; provenance DTB/upgrade
RAM yang menjelaskan laporan sekitar12GiB masih ditanyakan ke user.

ADT XNU lama mendeklarasikan satu rentang kontigu **[0x100000000,0x270000000)**,
yaitu4..9,75GiB. Rentang itu melintasi **gap6..8GiB** yang tidak ada di live banks.
Jika peta live sesuai hardware, page allocator bisa memberi alamat di celah ketika
penggunaan memori bertambah. Ini kandidat penyebab stall yang konkret, tetapi
belum terbukti sebagai penyebab boot ini. Jangan langsung menyatakan bug sudah fixed.

Probe /dev/mem tersedia tetapi CONFIG_STRICT_DEVMEM=y dan baca signature kernel
tidak mengembalikan byte. Tidak ada signature/telemetry RAM pasca-reset yang bisa
divalidasi; itu **bukan** bukti RAM XNU telah dihapus. Tidak ada bypass proteksi,
module load, memory write atau pembacaan MMIO dilakukan.

## Image kontrol: base tetap4GiB, batasi ukuran2GiB

[Download timelm-0090-ios-rw-c1-wdtstop-nostatus-ram2g.img](https://pixeldrain.com/u/216CAPu5),
[manifest dan verifikasi perbedaan](evidence/0090-nostatus-ram2g-build.json).

```text
trial  0090-ios-nostatus-ram2g-r40078086391
SHA256 8012dcdaabd349f40c9d07b70831f8afbb5f8f2b33d4a1751b59c6663d7e69f6
RAM    base0x100000000 size0x80000000 => [4GiB,6GiB)
```

```bash
fastboot boot timelm-0090-ios-rw-c1-wdtstop-nostatus-ram2g.img
```

**Sudah diuji HP; hasil terbaru ada pada tautan di atas.** Rentang baru sepenuhnya berada di bank live/SystemRAM,
tidak overlap reserved-memory atau FDT memreserve live/static. Base kernel sama,
sehingga alamat load tidak dipindah. Shim identity map sekarang hanya mencakup
di bawah8GiB; jangan langsung memindah kernel ke bank8GiB tanpa audit/perubahan
shim. Kapasitas2GiB lebih kecil bisa mengubah memory pressure/jetsam/timing.

Kernel CI40078086391 dan SHA256 sama persis. Shim JOBS56; kernel/shim/DTB/init,
semua properti ADT selain chosen/dram-size, dan semua argumen selain trial identik
nostatus. Payload berbeda hanya mem_size, field ADT itu dan buffer trial.
10 kernel segments serta auxiliary RAMdisk segment identik/terverifikasi.
Tidak ada perubahan GPU/SMP/clock/ufslogsecs/cache policy/rootfs atau partisi.
Live RAM audit/bounds, payload/ADT/DTB, perbandingan byte dan upload hash sudah dicek.

## Langkah test dan roadmap setelahnya

1. Tes image2GiB. Seperti nostatus, angka HB/I89/P90 memang tidak ditampilkan.
   Tunggu sekitar3menit setelah logo; catat apakah UI muncul, tetap logo atau reboot.
2. Sambungkan ADB root/recovery. Pull raw tail ke file baru dan verifikasi trial
   ram2g/draw0. Bandingkan HB/flush/IRQ, raw event, UFS dan memory pressure dengan
   kedua baseline; jangan memakai ring lama jika kernel tidak mencapai flush baru.
3. Jika progres melewati titik sebelumnya, ulang A/B untuk membedakan pengaruh
   hole RAM dari batas kapasitas/timing. Periksa jetsam/OOM; jangan menyebut GUI
   selesai hanya karena heartbeat lebih lama.
4. Jika peta live/provenance dikonfirmasi, tambahkan RAM-window coverage check
   yang menolak hole/overlap reserved dan menyatakan static size0 unverified.
   Ubah default high window setelah validasi HP. Saat ini gunakan ADT2GiB eksplisit
   untuk tes baru, bukan default lama yang melintasi gap.
5. Multi-bank XNU/upper bank yang lebih besar adalah pekerjaan terpisah. Audit
   loader identity-map limit, pmap physical-layout assumptions dan firmware/SMEM
   topology dahulu. Pertahankan fallback image serta raw evidence setiap trial.

Tidak ada kernel baru yang diperlukan untuk tes2GiB ini.
