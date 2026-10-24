# Hasil 0090-diag dan langkah berikutnya: nostatus

**Update:** nostatus sudah diuji/dipull, draw0 terverifikasi namun tetap HB62/
flush6. Audit menemukan default RAM window melintasi gap pada live Android FDT.
**Ikuti [hasil nostatus dan trial RAM2GiB](0090_NOSTATUS_RESULT_AND_RAM_WINDOW.md)**
untuk checkpoint/image utama berikutnya. Instruksi nostatus di bawah adalah riwayat.

2026-10-24. User meminta cek recovery; forwarded ADB terhubung dan raw tail GPT
ios/sda31 berhasil dibaca read-only,4198400byte. Trial terverifikasi
`0090-ios-diag-r40078086391`. [Console](evidence/0090-diag-console.txt),
[metadata lengkap](evidence/0090-diag-phone-pull.json),
[laporan layar](evidence/0090-diag-screen-report.json).

| Snapshot terakhir | Nilai |
|---|---|
| SWEETLOG | flush6,45760console bytes |
| HB/T | 62/103090 |
| S/P/C/R | 5/4/4/0 |
| UFS done/issued:phase | 10252/10252:0 |
| UFS W/E | 0/0 |
| IRQ enter/handler-done/full-Q6 | 103356/103356/103356 |
| Q | 6 |
| Raw event_kind/event_count/panic_draw_stage | 0/0/0 |
| Status draw enabled | 1 |
| Timer entry ctl/cval | 5/3011128039 |

Header UFS opcode2a adalah write logger saat snapshot; footer user sebelumnya
menampilkan read28/phase2. Kedua waktu berbeda. F3 pada header adalah tahap
menyusun header, normal; log_success_seq5 merujuk sukses sebelum flush6 sekarang.
Timerctl5 berarti ENABLE/ISTATUS aktif, IMASK clear. CVAL dekat entry IRQ yang
expired adalah keadaan wajar ketika interrupt timer diterima, bukan bukti timer
bermasalah. Seluruh IRQ pada snapshot melewati Q6; fase itu masih sebelum final
assertion/assembly return, bukan state CPU sesudahnya.

PC interrupted0xfffffe0007467fa8 pada kernel CI0090 yang sama cocok dengan
`ccsha256_ltc_compress+0x170`, instruksi NEON `ushl.2s v17,v16,v4`. Ini sampel
konteks hashing kernel, bukan laporan fault atau bukti crypto menyebabkan freeze.
PC userspace0x1ed3fe158 dari layar tidak memakai simbol kernel; slide/prosesnya
belum diketahui. Angka T5 pada transkripsi berikutnya tetap disimpan sebagai
ambigu, tidak menggantikan T118731 dari laporan layar pertama.

Console berisi exec SpringBoard/backboardd, empat swap/copy, earlybootcomplete,
dan CRASH driverkitd SIGKILL/jetsam ns1/code7 yang diikuti aktivitas boot/frame.
Tidak ada teks command UFS timeout atau laporan kernel panic yang tercapture.
Bytes sesudah committed total dalam blok terakhir nol, tidak ada suffix log baru.

## Batas kesimpulan

Snapshot HB62 mendahului HB70/Q6 yang terlihat diam. Tidak ada raw event pada
snapshot **belum meniadakan panic sesudah flush6** yang tidak sempat tersimpan/
tergambar. UFS idle/error0 juga bukan keadaan final phase2 yang dilaporkan user.
Layar yang diam belum membedakan IRQ/global stall, clock, dan stale scanout.
Tidak ada dasar mengubah crypto, allocator, GPU atau root dari hasil ini.

## Tes pembanding yang sudah siap

[Download timelm-0090-ios-rw-c1-wdtstop-nostatus.img](https://pixeldrain.com/u/Cz9JMX3u),
[manifest](evidence/0090-nostatus-build.json),
SHA256 `464e1fbd92d8f99235262ecf4a4d190bc34eaccbc245454ff3e68631e8f39257`.

```bash
fastboot boot timelm-0090-ios-rw-c1-wdtstop-nostatus.img
```

Log diag sudah diamankan, jadi boleh lanjut nostatus. Profil mempunyai kernel,
shim,ADT,DTB,init dan payload selain command line yang identik; hanya drawflag0
dan trial unik. **Tidak ada angka HB/I89/Q/P90 yang diharapkan tampil**, tetapi
telemetry/raw-event/header tetap dicatat. GUI copy/fade/console-panic/user mapping
tetap bisa menulis panel; tes hanya mengisolasi gambar status.

Tunggu sekitar tiga menit dengan stopwatch setelah logo Apple tampil, catat
UI/animasi/reboot jika ada. Kembali recovery dan sambungkan ADB. Agent pull ke
file terpisah, verifikasi trial `0090-ios-nostatus-r40078086391` dan
TIMELM90.draw_enabled0. Jangan menafsirkan tidak adanya angka sebagai freeze baru.

Jika nostatus terus flush dengan HB/IRQ melewati titik sebelumnya, ulang A/B
untuk membedakan kontribusi status drawing dari variasi timing. Jika tetap
berhenti, bandingkan raw event,Q,timer/UFS dan lama pengujian. Baru tentukan
instrumentasi/isolasi berikutnya; tidak perlu build/reflash baru untuk tes ini.
[Panduan header dan marker0090](0090_DIAGNOSTIC_TRIAL.md).
