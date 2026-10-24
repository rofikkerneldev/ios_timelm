# 0088: observer layar dan header liveness tanpa ketergantungan pada console

2026-10-24. **Build CI sukses dan image sudah diunggah:**
[40067579578](https://github.com/rofikkerneldev/ios_timelm/actions/runs/40067579578),
source `f004673e690618509c994bc32495be4ffbe313ce`.
**Sudah diuji HP:** footer mencapai HB=71, enam copy frame selesai, kemudian
user melihat status diam. Recovery pull memverifikasi trial dan header HB=62 /
flush=6. [Analisis dan image pembanding CPU idle](0088_PHONE_RESULT_AND_NOIDLE.md)
menjadi langkah tes terbaru. Target GPT tetap `ios`.

## Image tes dan langkah berikutnya

[Download timelm-0088-ios-rw-c1-wdtstop-diag.img](https://pixeldrain.com/u/nYeQHR4s),
[manifest](evidence/0088-build.json).

```text
trial  0088-ios-diag-r40067579578
SHA256 d8e64b2747f790c67cb972645e813669ef716ebeadaa9f54b85d528dddfc13ba
kernel 95f58a5f18605eab0854975de0a275165471d793564622503c59084fe248dd56
```

```bash
fastboot boot timelm-0088-ios-rw-c1-wdtstop-diag.img
```

Profil: `rd=ufsroot0 ufsroot=ios ufsrw=1 rootrw=1 cpus=1`,
`timelm_wdt=stop timelm_diag=1 sweetbeat=1 sweetlog=1 ufslogsecs=10`,
`sweetfb_noconsole=1 sweetfb_hz=5`; touch/keys/USB dimatikan.
Shim dikompilasi lokal dengan JOBS=56; kernel dari CI di atas. Hash/ukuran upload,
marker/simbol diagnostik, dan 10 segmen payload sudah diverifikasi.

1. Boot image di atas. Jika tetap pada logo, tunggu sekitar tiga menit dengan
   stopwatch; catat jika reboot atau berubah lebih awal.
2. **Sebelum recovery**, foto/catat kedua baris footer dua kali dengan selang
   15–30 detik. Sertakan HB/T, S/P/C/R dan L/F/W/U/OP/E. Ini bukti yang tetap
   dibutuhkan bila logger tidak bisa menyimpan state terakhir.
3. Kembali ke recovery dan sambungkan forward ADB. Pull hanya dari `ios`:

```bash
SWEET_LOG_PARTITION=ios \
SWEET_ADB_BIN=/home/rofikkernel/alpha/out/host/linux-x86/bin/adb \
SWEET_ADB_HOST=127.0.0.1 SWEET_ADB_PORT=15037 \
sh tools/sweet-log-pull.sh "$HOME/work/0088-console.txt" \
  2> "$HOME/work/0088-console.meta.txt"
```

Verifikasi trial dari JSON `TIMELM_DIAG` pada stderr walaupun console tidak
mencetak heartbeat lagi. Tidak ada printf heartbeat pada mode diagnostik;
ketiadaan baris itu sendiri bukan kegagalan observer. Simpan file `.bin` asli.

## Alasan perubahan

Trial `0087-ios-gui-log-r39984162472` sudah ditunggu **10 menit dengan stopwatch**.
Pull recovery memverifikasi SWEETLOG sequence 6, 41158 console bytes, heartbeat
terakhir 8/timer 59240. Root ios benar; UMD/launchd cache selesai; exec SpringBoard
tercatat, tetapi backboardd/swap belum tercapture dalam snapshot terakhir ini.
[Log](evidence/0087-ios-10min-console.txt),
[metadata](evidence/0087-ios-10min-pull.json).
Tidak ada teks tambahan di bagian blok terakhir yang ditulis setelah committed
total. Bytes nonzero di blok ring yang belum ditulis cocok dengan backup sebelum
logging; bukan bukti output boot yang lebih baru. Ini mengulang gap observasi pada
filesystem/partisi baru; menunggu lama saja tidak membedakan logger dari kernel.

## Perilaku opt-in timelm_diag=1

- Heartbeat menaikkan counter atomik, mengambil absolute time/timer IRQ dan
  menggambar status langsung pada mapping framebuffer yang sudah dipublikasikan.
  **Tidak memanggil printf pada loop observer**, tidak mengambil mutex UFS,
  IOKit surface lock atau display workloop. Menghindari observer tertahan pada
  jalur console yang sedang diperiksa. Interval profil akan satu detik.
- Footer hitam 64 baris, dua baris font putih, dicadangkan pada bagian bawah
  panel. Present/fade tidak menimpanya; sebagian bawah UI terpotong secara sengaja
  pada profil diagnostik. Console startup masih dapat menggambar sementara.
- Counter `S` dihitung sebelum lock submit, `P` saat masuk present, `C` setelah
  setidaknya satu copy layer selesai pada present itu, `R` menghitung layer yang
  ditolak. Surface default yang memang langsung merupakan framebuffer tidak
  dihitung sebagai copy atau reject. Counter bukan bukti isi piksel UI benar.
- Logger tetap menulis header tiap interval walaupun jumlah console bytes tidak
  berubah. Ini memisahkan console senyap dari worker logging yang masih berjalan.
  Error memperbarui state sebelum worker keluar; observer tidak bergantung pada
  pesan error console yang tidak dapat di-flush worker yang gagal.
- UFS mencatat jumlah command/completed, opcode terakhir, waiters dan fase tanpa
  mengubah lock/transport. Counter waiter berpasangan walau flag enable berubah.

Tanpa boot-arg diagnostik, jalur console/viewport/logging lama tetap dipakai.
Counter diagnostic hanya mengamati; tidak mengubah hasil I/O, SEP atau entitlement.

## Cara membaca footer

```text
D88 HB=... T=... S=... P=... C=... R=...
L=... F=... W=... U=completed/issued:phase OP=... E=...
```

| Field | Arti |
|---|---|
| HB / T | Jumlah wake heartbeat / virtual timer IRQ count |
| S / P / C / R | Submit / present / present dengan copy selesai / layer ditolak |
| L | Sequence logger terakhir yang write+sync-nya sukses |
| F | Logger: 0 idle, 1 tunggu mutex, 2 data, 3 header, 4 sync, 5 error, 6 startup |
| W | Thread sedang mencoba memperoleh mutex UFS |
| U | Command selesai / diissue : fase (0 idle, 1 prepare, 2 doorbell wait, 3 error) |
| OP | Opcode SCSI terakhir, hex; 28 read, 2a write, 35 sync |
| E | Errno UFS/logger terakhir, sticky; bisa berasal dari error yang sudah dilewati |

Catat/foto footer pada setidaknya dua waktu berbeda, terutama sebelum kembali
ke recovery. HB yang berubah membuktikan observer mendapat CPU; footer yang diam
sendiri belum menunjukkan instruksi penyebab stall. Jika HB bergerak tetapi L
tidak, perhatikan F/W/U/E. Jika HB/L bergerak tetapi C tidak, arahkan analisis ke
present/renderer/IPC. Jika C bergerak tetapi UI salah, periksa format/crop/lifetime.

## Header disk dan decoder

SWEETLOG versi 1, ring size dan layout console tetap sama. Di offset 64 header
4096 byte, extension `TIMELMDG` versi 1 menambahkan ukuran 208 byte, 16 counter
u64 serta trial string 64 byte. `tools/sweet-log.py` mencetak JSON `TIMELM_DIAG`
ke stderr dan tetap menulis console text ke output seperti sebelumnya.

Snapshot extension dibuat sebelum write header/sync; F=3 pada snapshot adalah
normal. `log_success_seq` biasanya merekam sequence sukses **sebelumnya**,
sedangkan SWEETLOG seq adalah header yang sedang ditulis. Field dibaca atomik
secara terpisah, bukan transaksi snapshot seluruh mesin. Absolute times adalah
tick mentah. Trial pada extension mengidentifikasi boot meskipun console kosong.

Header baru tetap bergantung pada worker UFS untuk tersimpan. Footer diperlukan
untuk membedakan worker storage yang berhenti dari observer yang masih hidup.
Periodic header write menambah aktivitas I/O saat console senyap; ini profil
diagnostik, bukan bukti penyebab sebelumnya sudah diperbaiki.

## Tambahan workflow Sweet/Topaz: crash dan stack sample

Referensi user sudah diperiksa:
[decoder Sweet](https://github.com/dipa-studio/ios-sweet/blob/main/tools/sweet-log.py),
[symbolicator Sweet](https://github.com/dipa-studio/ios-sweet/blob/main/tools/sweet-crash.py).
Kedua tool sudah diwarisi timelm. Decoder lokal menambahkan validasi panjang dan
extension TIMELMDG tanpa mengganti susunan ring console Sweet. Gunakan versi lokal
untuk memperoleh counter 0088. Sumber partisi tetap **ios**, bukan userdata seperti
contoh Sweet; recovery/ADB hanya untuk membaca log setelah tes XNU selesai.
Perbandingan pada raw ring ios 0087 sepuluh menit menghasilkan console bytes
identik antara decoder upstream dan lokal; bukan perbedaan decoding yang
menjelaskan gap heartbeat pada capture tersebut.

`CRASH` berasal dari hook exit proses, mencakup signal, exception code, shared-cache
slide, Mach-O header, register/backtrace dan exit reason bila tersedia. Record
SIGKILL/jetsam tidak otomatis membuktikan fault instruksi atau kernel panic.
`SMP` adalah sampel saved user registers; label ini tidak berarti crash atau CPU
tambahan. Ring tidak menjamin semua proses exit menghasilkan laporan, dan log
yang berhenti di-flush tidak dapat membuktikan tidak terjadi crash setelahnya.

Symbolicator sudah diverifikasi dengan shared cache **20H392 yang sama dengan
root iOS timelm**, bukan cache firmware lain. [Hasil](evidence/sweet-symbolication-check-20261024.json):

- Sampel SpringBoard 0086: t0 `_mach_msg2_trap + 8` /
  `_mach_msg2_internal + 76`; t1 `___workq_kernreturn + 8` /
  `__pthread_wqthread + 360`. Saved state konsisten dengan jalur IPC/workqueue;
  belum mengidentifikasi server IPC yang ditunggu atau membuktikan hang.
- CRASH driverkitd 0087 historis: PC `_read + 8`, LR
  `__NSReadFromFileDescriptorWithProgress + 192`, backtrace pembacaan NSData.
  Signal 9 / reason namespace 1 code 7 tetap berarti terminasi jetsam per-process
  memory limit. Ini bukan bukti kesalahan disk atau penyebab GUI tertahan.
- Snapshot ios 0087 sepuluh menit tidak memuat record CRASH/SMP; sampler pada
  profil itu dimatikan. Ketiadaan record bukan bukti semua daemon sehat.

Untuk address runtime `A` pada shared cache dengan slide `S`, lookup **A - S**:

```bash
# Contoh nyata dari header sampel SpringBoard 0086, bukan slide untuk boot baru.
TIMELM_CACHE="$HOME/work/timelm-0086-full-log/cache/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64"
ipsw dyld a2s --image "$TIMELM_CACHE" 0x1c2611030
# 0x1c9111030 - 0x6b00000 = 0x1c2611030
```

Selalu gunakan slide dari header proses/sampel yang sedang dianalisis. Untuk
alamat executable utama, gunakan runtime minus `mh` plus preferred vmaddr Mach-O
executable itu; inherited helper mengasumsikan `0x100000000`. Helper tidak membaca
ROOT atau executable walaupun menerima argumen ROOT, jadi output `main binary`
hanya translasi alamat, belum lookup nama fungsi. Alamat kernel tidak memakai
shared-cache slide: gunakan kernel/symbols yang cocok dengan build yang dites.

Contoh helper untuk satu report yang utuh, dimulai dari header `slide ... mh ...`:

```bash
python3 tools/sweet-crash.py "$TIMELM_CACHE" "$HOME/work/ios16-root.img" \
  "$HOME/work/one-process-report.txt" > "$HOME/work/one-process-symbols.txt"
```

Pisahkan report per proses/sampel dan pertahankan header. Helper inherited hanya
menyimpan satu konteks slide/mh terakhir; jangan menjalankannya pada log campuran
tanpa mengaudit urutan header/interleaving. Simpan log asli tanpa filtering untuk
forensik; baris dapat terpotong/tercampur, sehingga cari `CRASH`/`SMP` juga di
tengah baris. Console saat ini mengandung NUL; pakai `rg -a` bila perlu.

**Urutan roadmap tetap:** tes 0088 yang sudah diunggah dahulu. Crash collection
tetap aktif tetapi profil mempunyai `sweetsample=-`, sehingga jangan mengharapkan
SMP periodik. Jika HB/L berjalan sementara GUI tertahan, repack terpisah memakai
kernel 0088 yang sama dengan `sweetsample=SpringBoard,backboardd` dan trial unik.
Source sampler sekarang mulai sekitar 90 s setelah start, berulang tiap 120 s,
maksimum 40 kali; waktu ini bukan deadline sejak logo. Bandingkan beberapa sampel
dan backtrace, lalu telusuri IPC/render dependency yang didukung bukti. Jika UFS/
logger gagal, sampel yang hanya dicetak console mungkin tidak tersimpan; utamakan
footer/fase storage lebih dahulu. Belum dibuat image sampling tambahan.

Pesan `SWEET TOUCH` Topaz menjelaskan bring-up FocalTech pada hardware Topaz.
Jangan menerapkan chip ID/clock/SE2 tersebut ke timelm; touch tetap off sampai
baseline GUI/liveness jelas dan hardware V60 sudah diverifikasi terpisah.

## Verifikasi dan batas scope

Patch 0088 berlaku setelah 0087; 88 patch telah diaplikasikan pada source upstream.
Kompilasi lokal C/CPP BSD, framebuffer dan console lolos. 14 regression checks
timer/SGI/payload/watchdog serta lima checks baru lolos: decoder lama, liveness
tanpa console, transfer terpotong, extension versi tak dikenal, dan kompilasi/
eksekusi draw code aktual untuk bounds, stride padding, enable gate, ABI, serta
pasangan waiter saat enable berubah. Barrier ARM diganti fence native hanya pada
harness host. CI juga menjalankan checks baru.

Logging hanya pada area **ios di luar HFSX** yang sudah diaudit/dibackup; carrier
ext4 tetap dipertahankan. Tidak ada perubahan GPT, Android, ESP, win, GPU, SMP,
filesystem layout atau policy jetsam. Profile/hash/CI artifact tercatat pada
manifest di atas. Jika kernel menunjukkan hasil berbeda, perlakukan itu sebagai data
diagnostik dan bandingkan dengan 0087, bukan langsung mengklaim GUI selesai.
