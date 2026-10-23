# timelm 0085: interrupt correction and phone test sequence

This build implements the first software stage of
[the boot roadmap](TIMELM_BOOT_ROADMAP.md). Physical confirmation remains pending.

Update: the user reports all three original images reboot after approximately
30 seconds while printing verbose ZALLOC startup callbacks. Test the
[quiet RAM-disk image](https://pixeldrain.com/u/bz3c6qFV) first. Its kernel,
ADT, static init, shim and DTB match the original rd image; only startup verbosity
and trial ID changed. See the latest section of [OPENCODE_NEXT.md](../OPENCODE_NEXT.md).

Changes:

- Virtual timer INTID 27, matching the supplied SM8250 DTB; physical timer 30
  in the shim diagnostic constants.
- Correct SGI1 encoding; CPU startup must observe a received SGI1 before it can
  publish successful CPU initialization. Startup failure panics explicitly.
- Release/acquire stage flags replace the shared-line cache invalidations.
- No invented GICR group-enable writes. Timed reporting uses absolute-time conversion.
- Timer and SGI1 counters appear in heartbeat output, together with the trial ID.
- BSD traces entry and return from the RTC wait. Console scrolling batches eight
  lines to reduce framebuffer copying.
- Builds regenerate the HIGH ADT by default, use one CPU, disable the inherited
  key/touch/USB probes, and inspect the embedded payload against the expected kernel.

## Local checks

All 85 patches apply to xnu-8796.141.3. The 12 regression tests pass, including
compiling the actual patched SGI expression against independently specified Arm
test vectors. Seven changed kernel translation units also pass local Clang 21
syntax checks using the previous CI's generated headers. The actual macOS build
and its post-build encoder check are the authoritative compilation checks.

The new DTB checker rejects the old timer-19 ADT and accepts the regenerated
timer-27 ADT. Boot manifests include image/kernel/shim/ADT hashes, trial ID,
source commit, and patch-series digest.

## Phone sequence

All trial images use HIGH RAM and `cpus=1`. Keep the existing iOS userdata image.
Use the named image from the final build report, not the generic intermediate
`shim/out/shim-boot.img`.

1. Boot the **rd** image first with `fastboot boot <rd-image.img>`. Record the
   full screen from boot until at least 90 seconds; the RTC wait normally takes
   up to 30 seconds. This profile uses the static RAM-disk init.
2. Look for `TIMELM IRQ FIX 0085: trial=... timer=27`, a CPU startup line with
   `SGI1 received=...`, and `returned from IOKitInitializeTime`. Heartbeats should
   advance every five seconds with growing `cpu0-timer` and a nonzero
   `cpu0-sgi1`. Final proof is `SWEET userspace: init running as PID 1` followed
   by `SWEET init: still alive` about every five seconds.
3. After that succeeds, boot the **ufs-ro** image to inspect UFS takeover, GPT,
   userdata selection and HFS mounting. This profile refuses block writes; iOS
   services may fail because their normal writable directories are read-only.
4. After successful storage checks, boot **ufs-rw** to attempt Apple's launchd
   and the existing iOS userland. It permits filesystem writes to userdata.
   Hardware touch, physical keys and USB probes remain disabled for isolation.

All profiles disable the on-disk persistent log (`sweetlog=0`), because the tail
reservation has not yet been verified against the actual filesystem extent.
An old `sweet-log-pull` result therefore cannot identify these trials. Preserve
the on-screen trial ID and video/photos instead.

If rd still stops during CPU startup, capture the last waiting/panic line and
GIC diagnostics. If it stops at the RTC wait with no growing timer counter,
investigate runtime timer routing/state before bypassing the wait. If rd runs
and UFS fails, focus on host state, DMA/SMMU, actual LUN/block size and GPT; another
userdata reflash is not the first diagnostic step.

## Rebuild

Kernel compilation uses `.github/workflows/xnu.yml` on macOS/Xcode. On the Linux
server, packaging compiles the shim's independent translation units concurrently,
up to `JOBS=56`; this shim has seven such files.

```bash
JOBS=56 PROFILE=rd TRIAL=0085-rd-mytrial tools/build-boot.sh high timelm-0085-rd-c1.img
JOBS=56 PROFILE=ufs-ro TRIAL=0085-ro-mytrial tools/build-boot.sh high timelm-0085-ufs-ro-c1.img
JOBS=56 PROFILE=ufs-rw TRIAL=0085-rw-mytrial tools/build-boot.sh high timelm-0085-ufs-rw-c1.img
pd upload shim/out/timelm-0085-rd-c1.img
```

Use the kernel artifact from the exact successful CI commit. Verify its checksum
and `build-provenance.json` patch digest before replacing `xnu/out/`.
