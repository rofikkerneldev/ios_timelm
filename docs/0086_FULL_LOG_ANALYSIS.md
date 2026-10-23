# Analisis transkripsi lengkap 0086, 2026-10-23

Sumber user: [eF9sp8hv](https://pixeldrain.com/u/eF9sp8hv),
`lgv60_xnu_0086_ufs_rw_2841-2849.txt`, SHA-256
`17a3babc34c9f49671ffd91c8a2de090bd18db102dad6030afc9941a451e0c74`.
[Salinan](evidence/0086-full-user-transcription.txt).

File ini menggabungkan sembilan screenshot 1000312841..2849, memotong sebagian
register dan menggabungkan pesan berulang. Ini bukan byte-for-byte log boot.

## Yang dipastikan oleh tambahan log

- Trial ID konsisten: `0086-ufs-rw-wdtstop-r39974714520`.
- SpringBoard hidup sebagai PID 26 ketika sampler mengambil saved user registers.
  Label `SMP` adalah sampler proses, bukan CPU tambahan atau laporan crash.
- Heartbeat muncul dengan timer count 79596, 84630, 86275, 88583. Scheduler/timer
  masih berjalan di antara screenshot dan daemon baru terus dieksekusi.
- Backboardd berulang kali tidak menemukan `IOAcceleratorES`. Pencarian
  `IOAccessoryManager` dan `AppleHPMDevice` juga tidak menemukan layanan, tetapi
  tidak membuktikan keduanya penyebab GUI tertahan.
- Securityd meminta selector 10 (wrap key) yang belum didukung stub AKS dan mendapat
  `kIOReturnUnsupported`. Return 0 dari selector lain tidak berarti seluruh
  perilaku SEP/keychain sudah benar. Jangan mengganti unsupported dengan success
  tanpa implementasi bentuk output/semantik yang benar.

## Symbolication SpringBoard

Shared cache arm64 diambil dari arsip SystemOS 20H392 yang digunakan root builder,
bukan dari firmware lain. Runtime address dikurangi shared-cache slide `0x6b00000`.
Lookup memakai `ipsw dyld a2s --image`, dengan cache simbol di direktori kerja.
[Hasil terstruktur](evidence/0086-springboard-symbols.json).

| Thread/register | Runtime | Unslid | Simbol |
|---|---|---|---|
| t0 PC | `0x1c9111030` | `0x1c2611030` | libsystem_kernel: `_mach_msg2_trap + 8` |
| t0 LR | `0x1c9122b18` | `0x1c2622b18` | libsystem_kernel: `_mach_msg2_internal + 76` |
| t1 PC | `0x1c91114f0` | `0x1c26114f0` | libsystem_kernel: `___workq_kernreturn + 8` |
| t1 LR | `0x1d869ac1c` | `0x1d1b9ac1c` | libsystem_pthread: `__pthread_wqthread + 360` |

Ini konsisten dengan jalur Mach IPC pada thread utama dan worker thread pada
workqueue. Saved PC/LR tunggal tidak menjelaskan pesan IPC, server yang ditunggu,
durasi wait, atau kondisi live semua thread. Tidak ada exception code, ESR/FAR,
signal atau `CRASH ...` yang membuktikan SpringBoard crash pada file ini.
Saat membangun symbol cache, ipsw memperingatkan parsing sebagian ObjC classes
gagal; empat nama fungsi C di atas berhasil di-resolve dan berada di image/section
yang sesuai. Backtrace lanjutan terpotong, sehingga kesimpulan tidak boleh lebih
spesifik dari bukti ini.

## Dampak terhadap langkah berikutnya

Tetap tes **0087-diag yang sudah dibuild**, tanpa build kernel baru:

1. Cari marker publikasi layanan kompatibilitas IOAcceleratorES dan canvas
   1125x2436. Ini tidak menambahkan akselerasi GPU/Metal.
2. Dengan matching spam dan sampler/heap-scan mati serta log AKS dibatasi,
   amati heartbeat setelah daemon iOS mulai. Bila heartbeat lanjut tetapi GUI
   belum muncul, fokus pada backboardd/SpringBoard/rendering dan pesan IPC/exec.
3. Cari swap/frame atau error pertama. Profil GUI boleh dicoba untuk menghilangkan
   overlay console setelah present pertama; console berhenti pada profil itu
   adalah perilaku yang disengaja.
4. Pesan `/tmp` tidak ada pada transkripsi ini. Audit image host menunjukkan symlink
   dan mode direktori target benar, tetapi live root HP belum diaudit. Ambil teks
   lengkap/path/errno sebelum memperbaiki root. Tidak ada dasar reflash saat ini.

Pendekatan SWEET berupa IOSurface + IOMobileFramebuffer + software renderer sesuai
dengan arah port ini; GUI tidak mensyaratkan GPU Adreno terlebih dahulu. Namun
parameter hardware tidak dapat disalin seluruhnya: V60 memiliki empat A55 dan empat
A77-class, bukan enam A55 SWEET. Pertahankan `cpus=1` untuk baseline. Khusus V60 ini,
`wdt=-1 wdt_test=no_user_checkin` tidak menggantikan stop watchdog APSS di shim;
pertahankan **`timelm_wdt=stop`** yang telah mengubah hasil reboot secara praktis.
