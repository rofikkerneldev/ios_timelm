# 0087 GUI: logo berhenti, bar merah dan Nexus EPERM

2026-10-23. Status: laporan user parsial, **full log akan dikirim**.
Profil diidentifikasi user sebagai versi GUI; runtime marker/hash belum disuplai.
Ini hasil tambahan setelah laporan 0087-diag menampilkan logo Apple.

## Observasi user

```text
dibagian ujung versi GUI habis animasi sebentar logo apple

SK[0]_ nexus_register terus tertutup hitam dan ujungnya rapportd(82): nxprov_create :1
```

Klarifikasi berikutnya:

```text
animasi apple diam bar merah tetap ada dan tiba tiba agak lama muncul itu,
saya akan kirim full log
```

Interpretasi yang dibatasi laporan: logo sempat beranimasi lalu diam, bar merah
tetap ada, dan setelah jeda muncul pesan yang ditranskripsikan di atas. Deskripsi
awal penutupan hitam belum menjelaskan luas area hitam atau apakah masih berubah.
Durasi total, reboot/tidak, heartbeat dan swap belum dikonfirmasi. Jangan mengubah
laporan ini menjadi klaim black-screen total, kernel hang, panic atau UI berhasil.

## Arti pesan berdasarkan source kernel 0087

Audit terhadap source hasil apply 87 patch di
`$HOME/work/timelm-0087/verify`, source commit `4ec36d1`:

- `bsd/skywalk/nexus/nexus_syscalls.c:171`, `__nexus_register()`: setelah
  `nxprov_create()` mengembalikan NULL, mencetak `SK_DSC(p, "nxprov_create: %d", err)`
  dan mengembalikan errno melalui syscall. Ini error jalur Nexus/Skywalk networking.
- `bsd/skywalk/os_skywalk_private.h:271`, `SK_DSC`: format nama proses dan PID;
  `rapportd(82)` berarti proses rapportd PID 82, bukan kode error 82.
- `bsd/sys/errno.h:90`: errno `1` adalah `EPERM`, operation not permitted.
- `bsd/skywalk/nexus/nexus.c:1444`, `nxprov_create()`: berdasarkan nexus type,
  memeriksa privilege register user-pipe, flow-switch, atau net-if sebelum membuat
  provider. `skywalk_priv_check_cred()` memanggil `sk_priv_chk()` lalu
  `priv_check_cred()` (`bsd/skywalk/core/skywalk.c:518`). Ini jalur kandidat untuk
  penolakan tersebut; subtype dan pemeriksaan yang gagal belum tercapture.
  Error dari validasi parameter provider juga diteruskan; satu baris belum cukup
  menentukan cabang penolakan secara pasti.

Pesan ini bukan log driver GPU/display. Tidak ada bukti dari potongan tersebut
bahwa penolakan rapportd merupakan dependensi yang menghentikan SpringBoard.
Jangan bypass privilege, mengubah daemon, atau mematikan Skywalk hanya untuk
menghilangkan baris terakhir yang terlihat.

## Hubungan dengan present dan console

Pada `AppleCLCD::present()` source 0087, `sweetfb_noconsole=1` mengatur
`sweet_console_muted` sebelum validasi/copy layer. `_cnputs()` berhenti menggambar
teks bila muted, kecuali saat panic. Profil GUI memang meminta perilaku ini;
profil diag menetapkan `sweetfb_noconsole=0`.

Namun, laporan logo beranimasi sendiri belum membuktikan asal gambar atau bahwa
present, mute dan copy berhasil. Bar merah juga belum diidentifikasi. Teks Nexus
yang terlihat setelah jeda tidak membuktikan seluruh kernel berhenti di syscall
tersebut. Tentukan waktu, profil, marker dan urutan swap dari full log dahulu.

## Langkah berikutnya

1. Analisis full log yang user akan kirim: pastikan trial ID/profil, marker service
   IOAcceleratorES/canvas, heartbeat terakhir dan progres timer, swap/layer/surface,
   exec backboardd/SpringBoard, serta crash/exception pertama jika ada.
2. Bedakan pesan terakhir yang tercetak dari aktivitas terakhir sistem. Periksa
   apakah output berhenti karena console mute atau tertimpa frame.
3. Jika GUI tidak menyediakan observasi itu, gunakan diag kernel yang sama untuk
   liveness/swap. Bukti seputar present menentukan apakah perlu instrumentasi
   bounded (accepted/rejected surface, copy duration/completion, heartbeat).
4. Telusuri privilege/entitlement Nexus hanya bila full log menunjukkan hubungan
   dengan kegagalan layanan yang diperlukan. Belum ada dasar untuk menjadikannya
   penyebab tunggal layar berhenti.

Tetap gunakan baseline dan filesystem yang sama selama perbandingan. Roadmap
display setelah bukti ini lengkap ada di [perbandingan Topaz](TOPAZ_DISPLAY_COMPARISON.md).
