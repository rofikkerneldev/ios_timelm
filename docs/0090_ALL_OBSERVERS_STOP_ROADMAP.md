# Handoff 0090: semua observer terlihat berhenti, animasi Apple glitch

2026-10-24. **Update:** patch0090 sudah diimplementasikan, kernel CI sukses,
dua profil dan kontrolRAM2GiB sudah diuji HP;
[hasil terbaru dan prioritas](0090_RAM2G_RESULT_AND_REVIEW.md); [scope/trial aktual](0090_DIAGNOSTIC_TRIAL.md). Rancangan di bawah juga
memuat pekerjaan lanjutan yang belum seluruhnya bagian patch0090.
User memperjelas hasil 0089: semua baris termasuk I89/HB awalnya bergerak lalu
diam. Animasi Apple sempat terlihat sedikit/terpotong dan mengalami glitch frame.
[Evidence 0089](evidence/0089-phone-pull.json), [analisis snapshot](0089_PHONE_RESULT.md).
Tidak perlu meminta user mengulang konfirmasi apakah I89 ikut diam.

## Kesimpulan yang berubah

Hipotesis **hanya thread heartbeat tertahan pada printf** semakin lemah:
heartbeat 0088/89 tidak memanggil printf, dan timer IRQ mempunyai strip tanpa
mutex/UFS/workloop yang terpisah. No-idle 0088 juga tidak mencegah gejala.
Namun, semua indikator berbagi framebuffer/scanout; kedua refresh juga memakai
mach_absolute_time. Layar yang seluruhnya diam belum membuktikan seluruh IRQ/CPU
berhenti. Header terakhir flush8/HB81 masih lebih awal dari HB84 yang dilihat user;
lama diam setelah HB84 belum diukur. Jangan menyebut zalloc_ext atau rapportd
sebagai penyebab hanya dari sampel/teks terakhir.

Glitch frame juga belum membuktikan penyebab stall yang sama. Driver menyalin
langsung ke buffer scanout aktif, tidak melakukan latch/double-buffer DPU nyata;
tearing karena CPU copy dan pemindaian bersamaan masih mungkin. Dua jalur
diagnostik juga menggambar strip masing-masing; itu perlu dipisahkan dari isi
animasi bila menilai foto/video.

## Audit source yang sudah dilakukan

- SweetSurface::kernelAddress mengembalikan base buffer/map; offset ditambahkan
  satu kali oleh present. Belum ditemukan double-offset pada jalur ini.
- Layout buffer memvalidasi bytesPerRow terhadap width/bpe. Present melakukan
  clipping dan validasi akhir terhadap panjang backing memory. Snapshot lama
  BGRA1125x2436 stride4608 masuk jalur copy empat byte per pixel; belum ada bukti
  bounds/pixel format salah dari snapshot 0089 yang terbatas.
- Mapping physical framebuffer memakai kIOMapWriteCombineCache. Source pmap
  mengarah ke CACHE_ATTRINDX_WRITECOMB, dan proc_reg.h mendefinisikannya sebagai
  MAIR0x44 Normal Non-Cacheable. Jangan mengasumsikan mapping ini Device atau
  menyalin perubahan cache Topaz tanpa memeriksa PTE/MAIR aktual. Register hardware
  saat stall belum dibaca, jadi konfigurasi runtime belum dibuktikan oleh audit ini.
- IRQ phase2/O yang lama terletak sesudah rtclock_intr/EOI/ISB tetapi **sebelum**
  entropy_collect dan sleh_interrupt_handler_epilogue. Entropy collector source
  memakai timestamp, buffer perCPU terbatas dan satu cmpxchg, tanpa mutex-loop;
  tidak ada dasar menghapus entropy sebagai perbaikan.
- sweet_console_muted membuka kembali drawing saat panic_active. Ini tidak
  menjamin panic selalu terlihat: jalur debugger/console/mapping dapat tertahan
  sebelum teks tergambar atau sebelum worker UFS mendapat CPU untuk flush.

## Implementasi berikutnya yang paling bernilai

1. **Tambahkan penanda awal panic/fatal fault yang independen dari console.**
   Hook pada jalur panic yang pasti, sebelum debugger/console locks; simpan
   bounded literal format, caller PC, dan context/ESR/FAR bila valid. Jangan
   memformat va_list atau dereference pointer user dari observer. Trace fatal
   kernel fault, bukan setiap recoverable copyin/page fault. Tambahkan recursion
   guard dan opsi direct marker kecil pada mapping yang sudah tersedia. Bila
   framebuffer/bus sendiri bermasalah, direct marker juga bisa gagal; jangan
   menjadikannya satu-satunya bukti.
2. **Lengkapi tahap IRQ.** Bedakan entry, sebelum/sesudah rtclock_intr,
   sesudah EOI/ISB, sesudah entropy, dan sesudah epilogue umum. Tetap simpan
   interrupted PC/CPSR, serta snapshot kontrol/deadline virtual timer bila
   aksesnya valid. Jangan membaca IAR untuk observasi tambahan: read itu
   meng-acknowledge IRQ. Jangan mengubah EOI, timer programming atau GIC init
   pada patch observasi ini.
3. **Pisahkan observasi dari write framebuffer.** Sediakan flag yang mematikan
   draw IRQ/HB tetapi tetap memperbarui counter/header; jika perlu, profil
   pembanding terpisah yang melewati kernel present-copy/fade. C yang berarti
   copy selesai harus tetap nol saat copy dilewati; catat skipped tersendiri.
   Perhatikan console/panic dan mapping default surface ke userland masih bisa
   menulis panel: bypass copy kernel saja bukan eliminasi semua akses framebuffer.
   Jangan sekaligus mengubah allocator, format, clock DPU, SMP atau root.
4. **Bila panic/fase belum memberi bukti:** telusuri IRQ-masked critical section,
   lock slow paths, timer rearm dan clock progress berdasarkan last-phase/PC.
   Observasi register GIC/timer setelah kembali recovery bukan state saat XNU
   stall karena recovery telah menginisialisasi ulang hardware. Preserved-RAM
   trace atau observer hardware terpisah memerlukan audit carveout/ownership dan
   recovery path sebelum menulis IMEM/reserved RAM; carrier bukan pengganti
   observer independen karena logger tetap bergantung UFS/CPU yang sama.

## Batas verifikasi dan paket handoff

- Pertahankan cpus=1, root GPT ios RW, watchdog-stop, geometry log yang sudah
  diaudit, dan sampler off. Jangan reflash root atau memindah tail log untuk tes ini.
- Gunakan extension header baru di ruang kosong 4096-byte header tanpa menimpa
  TIMELMDG offset64/208byte atau TIMELMIQ offset320/80byte; versi/ABI harus diuji.
- Tes penanda dengan context null, string panjang, recursion guard, disabled
  flag, dan mapping belum tersedia. Jalankan bounds/sanitizer pada fungsi draw
  aktual; pastikan tidak ada printf, alokasi atau lock pada jalur raw observer.
- Terapkan seluruh patch; compile translation unit yang berubah; jalankan checks
  boot/D88/I89 dan decoder compatibility. Baru build CI, periksa provenance/hash,
  simbol/hook disassembly, package shim JOBS=56, inspect payload lalu pd upload.
- Tes satu variabel/profil per boot. Catat ketiga baris **beserta PC dan phase**
  pada saat berhenti, serta durasi. Simpan raw tail sebelum trial berikutnya.

Roadmap ini menguji lokasi stall dan kemungkinan gangguan akses framebuffer.
Belum ada bukti cukup untuk memilih perbaikan GPU, cache policy, allocator,
entropy atau filesystem tertentu. GUI stabil belum tercapai.
