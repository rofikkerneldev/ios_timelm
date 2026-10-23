# Topaz → timelm: display dan roadmap setelah 0087

Audit 2026-10-23. Referensi Topaz dipin pada commit
[`e4772911e116ab4ab6c4ac1f38e6106fefe8b483`](https://github.com/MakrSas/ios-topaz/tree/e4772911e116ab4ab6c4ac1f38e6106fefe8b483).
Baseline timelm: kernel 0087, source commit `4ec36d1`, CI `39984162472`.
Update HP: user mengonfirmasi **0087-diag menampilkan logo Apple**, beberapa baris
`exec xpcproxy` dan bar merah; hasil setelah menunggu masih pending. GUI interaktif
belum terkonfirmasi. [Laporan](evidence/apple-logo-phone-report.txt).
Perbandingan source ini tidak menghasilkan image baru.

## Kesimpulan untuk langkah sekarang

Pendekatan Topaz berguna untuk evolusi display V60: IOSurface/IOMFB dahulu,
software rendering, kemudian pengelolaan buffer dan scanout, GPU belakangan.
Tetap uji **0087-diag**, lalu profil GUI yang sudah tersedia. Log 0086 membuktikan
userland dan SpringBoard pernah berjalan, tetapi belum membuktikan sumber masalah
berikutnya berada pada renderer, present, scanout, atau dependensi userspace.
Lihat [handoff dan download](../OPENCODE_NEXT.md) serta
[symbolication 0086](0086_FULL_LOG_ANALYSIS.md).

## Direct scanout berbeda dari GPU rendering

Ada tiga operasi terpisah: menggambar frame, memindahkan hasilnya ke buffer display,
dan display controller membaca buffer tersebut untuk panel.

```text
timelm 0087:
CoreAnimation/software → IOSurface → CPU copy → framebuffer ABL → panel

Topaz, perubahan 0092 → 0102:
IOSurface → direct MDP scanout untuk surface yang memenuhi syarat
         → kemudian copy ke back buffer + flip untuk menghindari tearing

Topaz, jalur GPU yang dilaporkan roadmap:
CoreAnimation/OpenGL ES → Mesa/Adreno → hasil frame → CPU copy → display
```

[0092](https://github.com/MakrSas/ios-topaz/blob/e4772911e116ab4ab6c4ac1f38e6106fefe8b483/xnu/patches/0092-topaz-direct-mdp-scanout.patch)
menambahkan scanout alamat fisik; tetapi
[0102](https://github.com/MakrSas/ios-topaz/blob/e4772911e116ab4ab6c4ac1f38e6106fefe8b483/xnu/patches/0102-topaz-copy-and-flip.patch)
mengganti jalur present itu menjadi `flipFrom(...)` bila back buffer tersedia.
Komentar source menjelaskan CoreAnimation dapat langsung menggambar frame berikut
ke surface yang sama; scanout langsung memperlihatkan frame setengah jadi.
Direct scanout masih menjadi fallback pada cabang tersebut. Roadmap
[README](https://github.com/MakrSas/ios-topaz/blob/e4772911e116ab4ab6c4ac1f38e6106fefe8b483/README.md#roadmap)
juga menyebut CPU masih menyalin setiap frame pada pekerjaan GPU dan rendering
langsung ke surface display sebagai langkah berikutnya. Jadi tabel README
"direct scanout" bukan alasan menganggap seluruh jalur terbaru sudah zero-copy.

Ini penelusuran patch terkait dan laporan upstream; bukan verifikasi hardware
Topaz atau rekonstruksi/test seluruh patch GPU 0900–0947.

## Perbandingan yang menentukan port V60

| Area | Bukti Topaz | Keadaan timelm / implikasi |
|---|---|---|
| IOSurface + AppleCLCD | Menyediakan kontrak display bagi iOS sebelum GPU | Sudah ada. 0087 memperbaiki canvas 1125×2436 dan menambah empty IOAcceleratorES; belum diuji HP |
| Present | Direct scanout, kemudian double buffer/copy-and-flip | Saat ini `AppleCLCD::present()` melakukan `memcpy` per baris ke framebuffer ABL; tidak memprogram alamat scanout DPU |
| RAM scanout | Allocator contiguous dengan mask di bawah 4 GiB | VM timelm HIGH adalah `[0x100000000, 0x270000000)`; tidak menyediakan halaman kelolaan di bawah 4 GiB untuk allocator tersebut |
| Cache | Topaz 0111 menghindari no-op dari konfigurasi coherent I/O Apple | Binary timelm 0087 sudah memiliki loop `dc cvac` dan `dc civac`; bukan bukti semua call site/mapping benar |
| Display MMIO | 0092 menulis VIG0 `0x05e05000`, CTL0 `0x05e02000` | DTB timelm menyebut MDSS `0x0ae00000`, DPU `0x0ae01000`, VBIF `0x0aeb0000`; offsets aktif masih perlu dipetakan |
| GPU | Adreno 610 + integrasi Mesa/userland | DTB timelm menyebut Adreno 650.2, GMU 650.2; firmware, power, SMMU dan submission memerlukan port tersendiri |

### RAM dan mapping

[0093](https://github.com/MakrSas/ios-topaz/blob/e4772911e116ab4ab6c4ac1f38e6106fefe8b483/xnu/patches/0093-topaz-scanout-contiguous-ram.patch)
mengganti pool fisik mentah dengan `IOBufferMemoryDescriptor::inTaskWithPhysicalMask`
dan `kIOMemoryPhysicallyContiguous`, mask `0x00000000fffff000` serta validasi akhir
buffer tidak melampaui 4 GiB. Alasannya termasuk mapping alamat di luar RAM XNU
sebagai Device memory yang membuat `bzero/memcpy` alignment-fault.

Implikasi untuk timelm: jangan menyalin allocator itu dan menganggap alokasi akan
berhasil pada window HIGH sekarang. Framebuffer ABL `0x9c000000` yang sudah ada
adalah area terpisah; keberadaannya tidak membuktikan RAM di sekitarnya bebas.
Perlu salah satu rancangan yang dibuktikan: pool low-RAM yang benar-benar reserved,
mapping Normal/cache policy dan lifetime yang tepat; atau kemampuan alamat/SMMU
SM8250 untuk buffer HIGH. **Batas 32 bit pada implementasi Topaz bukan bukti batas
hardware SM8250.** Jangan mengarang carveout dari ukuran RAM pemasaran. DTB statis
yang tersedia tidak memberikan live DDR/reservation map lengkap.

### Cache: audit binary mengubah diagnosis

Topaz [0111](https://github.com/MakrSas/ios-topaz/blob/e4772911e116ab4ab6c4ac1f38e6106fefe8b483/xnu/patches/0111-topaz-real-dcache-ops.patch)
menjelaskan `__ARM_COHERENT_IO__` membuat fungsi generic menjadi no-op.
Konfigurasi timelm memakai `__ARM_COHERENT_CACHE__` untuk koherensi CPU; ini bukan
macro coherent I/O tersebut. Disassembly **kernel yang sudah diupload** menunjukkan:

- `_flush_dcache` memanggil `_FlushPoC_DcacheRegion`.
- `_FlushPoC_DcacheRegion` menjalankan loop `dc civac` dan completion `dsb sy`.
- `_CleanPoC_DcacheRegion` menuju implementation dengan loop `dc cvac` dan `dsb sy`.

[Disassembly](evidence/0087-cache-disassembly.txt),
[hash kernel, source dan ekstraksi DTB](evidence/topaz-timelm-display-audit.json).
Ini menyingkirkan dugaan spesifik bahwa fungsi compiled itu hanya barrier/return.
Belum membuktikan present memanggilnya pada alamat/range yang tepat atau DMA sudah
koheren. Framebuffer fisik timelm saat ini dimap `kIOMapWriteCombineCache`; buffer
cached baru perlu kontrak clean/barrier/ownership sendiri. Jangan menambahkan
invalidate pada buffer yang masih digunakan CPU tanpa audit kepemilikan.

### Boot, CPU dan perangkat lain

Masalah ABL v4, Silver A53 tanpa 16K, dan emulasi LSE/LDAPR pada Topaz adalah
kebutuhan port tersebut. Timelm sudah melewati loader v2, initCPU dan launchd;
pertahankan baseline 16K, `cpus=1`, timer 27, SGI1 dan `timelm_wdt=stop`.
Tidak ada bukti terbaru yang meminta perubahan boot format atau emulasi A53.
Patch touch/Wi-Fi Topaz dapat menjadi referensi arsitektur, tetapi alamat GENI,
clock, firmware/PAS dan rail Topaz bukan konfigurasi LG V60.

## Roadmap eksekusi OpenCode

Kerjakan fase berdasarkan hasil sebelumnya; satu perubahan utama per trial.

| Fase | Pekerjaan konkret | Bukti selesai / keputusan lanjut |
|---|---|---|
| 0 — baseline 0087 | Boot diag yang tersedia, pastikan marker service dan canvas; amati heartbeat, exec/crash pertama, swap. Coba GUI bila present terjadi | Hasil HP beserta trial ID. Service matching saja belum membuktikan frame tergambar. Jika belum ada swap, telusuri renderer/IPC dahulu |
| 1 — observasi present | Jika swap ada tetapi UI belum benar: tambahkan counter bounded accepted/rejected surface, alasan format/range, durasi copy dan total frame; pertahankan heartbeat. Audit IOMFB swap/completion dan lifetime | Pisahkan tidak ada present, present ditolak, copy berjalan, dan scanout/format salah. Tidak perlu dump per-frame tanpa batas |
| 2 — jalur copy ABL | Pertahankan tujuan framebuffer yang sudah bekerja. Ukur bytes/frame dan waktu, audit crop/stride/channel order/mapping/barrier. Pertimbangkan cached console shadow + dirty batching bila scroll dominan | Frame software stabil dan UI terlihat; bandingkan profil console/GUI dengan kernel yang sama. Tidak mengklaim vsync hardware dari timer IOTimer |
| 3 — kontrak DPU/RAM | Baca state display SM8250 berdasarkan driver vendor/mainline dan handoff ABL: pipe aktif, address/stride/format, CTL flush, interface, IOVA/SMMU serta reserve RAM. Probe read-only hanya register yang dipastikan aman dibaca | Catatan register dan buffer lengkap untuk V60; addressability dan allocator/mapping terbukti. Jangan menulis konstanta VIG/CTL Topaz |
| 4 — double buffer | Setelah fase 3, implementasikan pool valid, copy ke back buffer, clean/barrier sesuai mapping, flip dan retirement berdasarkan event display yang benar. Feature gate baru default off, fallback copy ABL | Pola/frame tampil, tidak tearing atau reuse terlalu dini, allocation failure kembali ke fallback; reboot/test berulang |
| 5 — zero-copy opsional | Hanya surface eligible: validasi contiguity/addressability, format/stride/crop, tahan referensi sampai scanout selesai, sinkronkan producer/completion | Konsistensi frame dan ownership terbukti; bila tidak, copy-and-flip tetap jalur normal |
| 6 — GPU Adreno 650 | Track terpisah: audit firmware/GMU/power/clocks/SMMU, lalu submission/fence, Mesa + EAGL/CoreAnimation dan sharing buffer | Test GPU terukur sebelum integrasi UI. Patch 610 tidak dianggap driver 650 siap pakai |

Perbaikan API IOSurface Topaz 0131–0139 (values, attachments, client memory,
release protocol) boleh dipilih di fase 1–2 **jika trace membuktikan kontrak yang
kurang**. Misalnya [0134](https://github.com/MakrSas/ios-topaz/blob/e4772911e116ab4ab6c4ac1f38e6106fefe8b483/xnu/patches/0134-topaz-sweetsurface-client-address.patch)
menangani `IOSurfaceAddress`; jangan mengganti buffer client dengan alokasi baru
yang tidak memuat gambarnya. Empty IOAcceleratorES dari ide 0138 sudah masuk 0087.
Hindari mengimpor seri GPU/userland sekaligus ketika baseline GUI belum diketahui.
Pertahankan atribusi dan lisensi setiap source yang benar-benar diadaptasi.

Setiap build berikutnya: manifest source/CI/kernel/image hash, trial unik,
`timelm_wdt=stop`, root UFS-RW dan fallback tetap tersedia. Kernel via CI macOS;
shim lokal boleh `JOBS=56`. Verifikasi payload lalu `pd upload path/to/boot.img`.
Tidak perlu reflash userdata untuk iterasi kernel/display ini.
