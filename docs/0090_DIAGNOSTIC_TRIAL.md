# 0090: raw panic marker, IRQ tail stages, status drawing A/B

2026-10-24. Source `fe228e5b8816ec8ab56f075a8b28b626c04e5a2b`.
CI [40078086391](https://github.com/rofikkerneldev/ios_timelm/actions/runs/40078086391)
**sukses**, diag dan nostatus sudah diuji dan raw log tersimpan. Nostatus tetap
HB62/flush6; **[audit RAM dan trial2GiB](0090_NOSTATUS_RESULT_AND_RAM_WINDOW.md)**
menjadi checkpoint/image berikutnya. Belum ada hasil HP ram2g.
**[Hasil diag dan tes nostatus berikutnya](0090_DIAG_RESULT_AND_NOSTATUS.md)**:
trial terverifikasi, flush6/HB62, IRQ enter/done/full-Q6=103356,
raw-event0, UFS error0 dan empat copy selesai pada snapshot. Snapshot masih
lebih awal dari HB70 di layar. Tidak ada panic yang tertangkap sebelum snapshot;
kejadian sesudahnya belum direkam. [Transkripsi layar](evidence/0090-diag-screen-report.json):
Q6, HB70/T118731, P5/R0, I89 I118484/H69, PC0x1ed3fe158 U,
W0/E0 dan UFS `12013:2` OP28. User kemudian meminta cek recovery dan pull berhasil.
Durasi stopwatch akhir/L/done-issued footer lengkap belum tersedia.

Q6 adalah milestone draw terakhir, bukan bukti halt tepat di epilogue. H69
pada I89 lebih awal dari HB70, sehingga dua baris bukan snapshot serentak.
PC user perlu process/cache slide, bukan simbol kernel. UFS phase2 menunjukkan
command completion wait pada saat counter disalin; OP28 adalah read. Source
menetapkan timeout5s dan default ufswait0 (polling). Jika layar tetap seperti ini
selama tiga menit, timeout tidak dapat dinilai hanya dari layar: poller/clock
mungkin tidak maju atau scanout/status sudah stale. Ambil raw log sesudah recovery
sebelum memilih perbaikan storage atau trial berikutnya.
Root tetap GPT ios RW, cpus=1,
watchdog-stop, idle normal, sampler off.

## Download dan urutan tes

| Profil | Image | SHA256 |
|---|---|---|
| diag, tes dahulu | [cb3mvTSS](https://pixeldrain.com/u/cb3mvTSS) | 68b45e6b69da51360152bc0a6903b098782365eac3d05e4efd61e7b7e50df4af |
| nostatus, pembanding | [Cz9JMX3u](https://pixeldrain.com/u/Cz9JMX3u) | 464e1fbd92d8f99235262ecf4a4d190bc34eaccbc245454ff3e68631e8f39257 |

```bash
fastboot boot timelm-0090-ios-rw-c1-wdtstop-diag.img
# Sesudah log diag disimpan, tes pembanding:
fastboot boot timelm-0090-ios-rw-c1-wdtstop-nostatus.img
```

[Manifest diag](evidence/0090-diag-build.json),
[manifest nostatus](evidence/0090-nostatus-build.json).
Kernel CI sama, shim JOBS=56, semua komponen/payload di luar buffer command line
identik. Hanya flag timelm_status_draw dan trial berbeda. Provenance, simbol/hook
disassembly, 10 segmen payload/ADT/DTB, serta hash/ukuran upload sudah diverifikasi.
Trial: `0090-ios-diag-r40078086391` dan `0090-ios-nostatus-r40078086391`.

Tes diag sekitar tiga menit. Catat tiga baris termasuk Q hijau di kanan I89;
label I89 tetap dipakai walaupun kernel0090. Jika panel berlabel P90 muncul,
foto ketiga barisnya. Kembali recovery dan sambungkan ADB sebelum mencoba
nostatus. Pull memakai decoder lokal terbaru dan file berbeda per trial:

```bash
SWEET_LOG_PARTITION=ios \
SWEET_ADB_BIN=/home/rofikkernel/alpha/out/host/linux-x86/bin/adb \
SWEET_ADB_HOST=127.0.0.1 SWEET_ADB_PORT=15037 \
sh tools/sweet-log-pull.sh "$HOME/work/0090-diag-console.txt" \
  2> "$HOME/work/0090-diag-console.meta.txt"
```

Verifikasi trial pada TIMELM_DIAG serta JSON TIMELM_IRQ/TIMELM90. Simpan raw.bin.
Untuk nostatus gunakan nama output baru, verifikasi draw_enabled=0, pakai stopwatch
tiga menit lalu recovery/pull. Tidak ada status angka/P90 yang diharapkan tampil
pada nostatus. Tidak perlu reflash root.

## Implementasi dan batas scope

0089: semua baris awalnya bergerak lalu diam, animasi Apple glitch.
[Evidence](evidence/0089-phone-pull.json). Penyebab IRQ/global stall, panic,
clock dan framebuffer/scanout belum terpisah. PC zalloc_ext lama bukan fault PC.

**sweet_early_panic sudah ada** dari patch0010/0012, memakai _doprnt dan backend
framebuffer lama. Hook0090 mendahuluinya di panic_trap_to_debugger. Hook kedua
menangkap fatal saved-state64 sebelum panic_with_thread_kernel_state upstream.
Jalur debugger/panic lama tetap dijalankan.

Hook raw hanya merekam angka/alamat, tidak membaca format/va_list atau context
pointer generik/user. Fault hook memakai saved-state64 valid yang memang diterima
jalur fatal upstream. First-event guard mempertahankan register awal; entry
berikutnya hanya menambah event_count. Tidak ada printf, alokasi, mutex, workloop
atau UFS dalam hook. Jika mapping tersedia dan draw aktif, tiga baris menjadi merah:

```text
P90 EVENT=1/2 CALL=... PC=...
ESR=... FAR=... LR=...
FMT@... IRQ-Q=...
```

EVENT1 adalah panic generik, sehingga fault PC/ESR/FAR bisa nol; EVENT2 adalah
fatal saved-state64. CALL adalah caller kernel, FMT@ alamat literal format/message,
bukan isi string. Foto ketiga baris sebelum recovery. Event di RAM belum tentu
ter-flush bila kernel berhenti sebelum logger berjalan. Tidak melihat marker
belum meniadakan panic jika mapping/scanout/bus atau hook belum tersedia.

## Q memperluas observasi IRQ

Dua glyph hijau paling kanan strip I89 menampilkan Q. Pada draw cycle yang
maksimum sekali per detik, tiap update Q menyentuh area32x32pixel. Counter dan
fase tetap diperbarui setiap timer IRQ CPU0.

| Q | Tahap |
|---|---|
| 1 | Sesudah entry observer, sebelum prologue |
| 2 | Prologue selesai, sebelum rtclock_intr |
| 3 | rtclock_intr kembali, sebelum EOI |
| 4 | EOI+ISB dan observer done lama selesai |
| 5 | entropy_collect kembali |
| 6 | Epilogue C kembali, sebelum final preemption assertion dan assembly return |

I/O/F lama tetap berarti0089; O/F2 belum berarti epilogue selesai. irq_full_done
menghitung Q6 terpisah. Q yang terlihat adalah draw cycle terakhir, bukan selalu
fase CPU saat foto. Normalnya Q6 terlihat setelah cycle selesai; scanout membeku
juga dapat membuatnya diam. P90 menahan normal status draw agar event pertama
lebih lama terlihat. Ini menambah pekerjaan IRQ dan dapat mengubah timing.

CNTV_CTL_EL0/CNTV_CVAL_EL0 dibaca pada entry timer dan disimpan, tanpa mengubah
programming timer/GIC. Ini register entry terakhir, bukan state saat recovery.
CVAL expired/ISTATUS aktif saat IRQ timer bisa normal.

## Dua profil dari kernel yang sama

1. **diag**, timelm_status_draw=1: tes dahulu sekitar tiga menit. Jika diam,
   catat I89 termasuk Q/PC/F dan kedua baris D88 dua kali berselang30s. Jika P90
   muncul, foto ketiga baris. Recovery/pull dahulu sebelum boot berikutnya.
2. **nostatus**, timelm_status_draw=0: status HB/I89/Q/P90 tidak digambar, tetapi
   counter, raw-event recording dan periodic header tetap berjalan. Tidak ada
   angka status yang diharapkan di layar. Pakai stopwatch tiga menit, kemudian
   recovery/pull dan verifikasi trial nostatus. Tes setelah hasil diag disimpan.

Keduanya mempertahankan region96rows, GUI present-copy/fade, console/panic behavior
serta surface/scanout. NOSTATUS hanya mematikan gambar status; kernel/user GUI
masih dapat menulis framebuffer. Jika nostatus terus flush HB/IRQ/L setelah waktu
ketika diag biasanya diam, ulang A/B untuk menilai pengaruh timing. Ini belum
membuktikan akar masalah atau memperbaiki GUI.

## Header dan checks

SWEETLOG/D88/I89 kompatibel. TIMELM90 v1,128byte di offset448 menambah14u64:
event_kind,event_count,caller_pc,fault_pc,fault_lr,esr,far,format_pointer,irq_stage,
irq_full_done,timer_ctl,timer_cval,draw_enabled,panic_draw_stage. Panic draw stage0
belum dicoba,1 masuk,2 selesai. Semua di header4096byte; ring/lokasi tail ios tetap.
Decoder mengeluarkan JSON TIMELM90 ke stderr. Snapshot per-field tidak transaksional;
penyimpanan tetap bergantung logger/UFS.

90 patch apply; empat translation unit UFS/framebuffer/IRQ/debug compile lokal.
Boot14, D885, I892 dan raw-marker2 checks lolos. Native ASan/UBSan memeriksa bounds,
invalid format pointer yang tidak dibaca, first-event/recursion, mapping belum
tersedia, draw disabled, ABI/decoder lama/unknown-version dan Q-only draw bounds.
IRQ test aktual memastikan counter maju saat status draw dimatikan. Barrier ARM
diganti fence native hanya di harness. CI menjalankan checks baru juga.

Jika dua profil tetap berhenti tanpa event bukti, lanjut audit IRQ-masked critical
sections/timer rearm/clock atau trace dengan media independen setelah audit lokasi.
Jangan menghapus entropy atau mengubah allocator/GPU/SMP/cache/filesystem tanpa bukti.
