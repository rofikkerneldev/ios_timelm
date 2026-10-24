# LG V60 / timelm boot investigation and execution handoff

**Current layout update, 2026-10-24:** iOS moved to GPT `ios`; use
[the current partition handoff](IOS_PARTITION_NEXT.md) and `ufsroot=ios`.
The userdata geometry/images below are historical. Do not enable their tail
logging on the new layout without a fresh read-only audit.

Prepared 2026-10-23 for GPT-6.1-Sol. Investigated repository HEAD `aeb5f8f`.
Scope of this turn: analysis and planning. No kernel/shim implementation changes,
build submission, upload, flash, or phone boot was performed.

**The highest-priority original boot blocker is the timer IRQ mismatch: the supplied
LG V60 DTB specifies virtual timer INTID 27, while the generated ADT and shipped
images use 19. Patch 0083 then introduced a separate, definite SGI encoding bug.**
Fix and validate interrupts before investigating the iOS filesystem. A successful
physical boot has not yet established the complete causal chain.

## Evidence and what has actually booted

The original OpenCode session was read directly from its local SQLite database,
read-only. Relevant user messages are preserved under [evidence](evidence/):

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| [MID log](evidence/mid-user-log.txt) | XNU reaches CPU1 `initCPU`, with IRQs masked | Timer delivery, usable SMP, root mount, PID 1 |
| [HIGH UFS log](evidence/high-ufs-user-log.txt) | Same CPU1 milestone; paste contains repeated output | A clean chronology or successful UFS access |
| [Single-CPU log](evidence/c1-user-log.txt) | `selected=1`, CPU initialization completes, BSD prints buffer-header counts | Which exact image ran, root mount, launchd |
| [Static audit](evidence/static-audit.json) | DTB timer cells, image hashes, embedded ADT values, all 10 kernel segments checked against local kernel | Runtime interrupt delivery or storage correctness |

The single-CPU log uses the older CPU completion wording, consistent with a
pre-0083 kernel. Calling it definitely stale was too strong: no image hash or boot
identifier accompanies it. It remains valid evidence of an earlier single-CPU
boot reaching BSD. Missing early messages on a wrapping/scrolling screen cannot
alone prove a wrong kernel. No subsequent 0084 phone result was found in this session.

Current local artifacts match the previous handoff's hashes:

| Artifact | SHA-256 |
|---|---|
| `xnu/out/kernel.development.sweet` | `b8b3375a569fbce0f26bf3fba3fe49dc2a59a010c89e0a224df184b3c696ab75` |
| `shim/out/high-0084-c1.img` | `a12cee8653fb2f62604df504ff0b5b153a511251b545091c4ad273405f5fbec7` |
| `shim/out/high-0084-smp8.img` | `592b4b4680e0adf70808f299ef4c17d7caefef8482eb97d11349205090b17ea3` |

Both 0084 images embed timer 19 and the current kernel, including patch 0083.
The Android boot image's `kernel` is the shim; XNU is in its `ramdisk` payload.
Check payload segments in order, including zero-file-size Mach-O segments; matching
only by virtual address can confuse segments sharing an address.

## Findings, ranked

### P0: Virtual timer routing is inconsistent with the supplied hardware DTB

`dtb/boot_unpacked/dtb`, node `/timer`, contains these three-cell interrupt tuples:

| Timer, in binding order | DT cells | Absolute GIC INTID |
|---|---|---|
| Secure physical | `1, 13, 0xff08` | 29 |
| Non-secure physical | `1, 14, 0xff08` | 30 |
| Virtual | `1, 11, 0xff08` | **27** |
| Hypervisor | `1, 10, 0xff08` | 26 |

PPI numbers are relative to INTID 16. The third tuple is virtual, per the
[Linux architected timer binding](https://raw.githubusercontent.com/torvalds/linux/v6.12/Documentation/devicetree/bindings/timer/arm,arch_timer.yaml).
The source in `tools/mkadt.py:42` sets `VTIMER_INTID = 19`; the ADTs embedded in both
0084 images confirm 19. `shim/shim.c:33` also assumes virtual 19 / physical 18.
The kernel default in SWEET.h is 19, inherited through patch 0004, with the ADT
override introduced by patch 0017.

Effect: `pe_init_fiq()` enables the wrong PPI, and `sleh_irq()` only treats the
configured INTID as a timer. Even if firmware leaves 27 enabled, an interrupt on
27 follows the wrong handler path. A counter can advance while timer IRQ delivery
is broken; deadline comparisons alone do not prove that sleeping threads wake.

This explains two observations plausibly:

1. SMP startup uses `IOSleep(1)`. If it never wakes, its nominal five-second timeout
   is never checked again.
2. After `using ... buffer headers`, BSD calls `IOKitInitializeTime()`, which waits
   up to 30 seconds for `IORTC`. This port provides no matching RTC service in its
   patch set. A broken timer can prevent that normal timeout from completing.

The mismatch is confirmed; attributing the phone's stall to it remains a strong
hypothesis requiring a timer-27 hardware test. The bundled DTB is a static input,
not proof of the exact runtime FDT after ABL edits. Capture runtime data if results
disagree. Do not generalize SWEET's timer wiring to all Qualcomm devices.

`tools/check-adt-vs-dtb.py` currently reports zero failures because it checks MMIO
addresses and CPU affinities, **not timer interrupts**. Missing nodes can also be
reported as informational rather than failures. Its success is narrowly scoped.

### P0: Patch 0083 regressed the SGI encoding

In `xnu/patches/0083-sweet-smp-diagnostics-and-recovery.patch`,
`SweetCPU::signalCPU()` changes INTID shift 24 to 4 and changes
Aff2/Aff3 shifts incorrectly. The previous expression was architecturally correct.

Correct `ICC_SGI1R_EL1` fields:

| Field | Bits |
|---|---|
| TargetList | 15:0 |
| Aff1 | 23:16 |
| INTID | 27:24 |
| Aff2 | 39:32 |
| IRM | 40 |
| RS | 47:44, when supported |
| Aff3 | 55:48 |

See [Arm's SGI explanation](https://documentation-service.arm.com/static/65ba63b032ae5f7841c42508)
and [Linux GICv3 definitions](https://github.com/torvalds/linux/blob/master/include/linux/irqchip/arm-gic-v3.h).

For CPU1 MPIDR `0x100`, SGI1 should be `0x01010001`; patch 0083 emits `0x00010011`.
That selects SGI0 and target-list bits 0 and 4, rather than SGI1 to Aff0=0.
The driver enables SGI1, so this can prevent both self-IPIs and cross-CPU IPIs.
It also affects `cpus=1`, because CPU0 sends a self-SGI. It cannot explain stalls
seen before 0083 existed, but it compromises all current 0083/0084 images.

### P1: Additional 0083 changes are unsound

- `GICR_CTLR_ENABLEGRP1NS = 0x2` is not a GICR group-enable bit. Remove that write
  and the invented group-enable macros. Redistributor control has different fields;
  group delivery involves the distributor and `ICC_IGRPEN1_EL1`, already handled
  elsewhere. Keep read-only diagnostics with correct field interpretation.
- `uint32_t sweet_cpu_stage[MAX_CPUS] aligned(64)` aligns the array, **not each
  element**. Eight flags occupy the same cache line. The comments promising one
  private cache line per CPU are false. Reader-side `dc ivac` can discard other
  dirty data on that line. Use release/acquire atomics for ordinary coherent CPU
  sharing; investigate actual coherence/mapping before adding cache operations.
  Reset-time publication to a CPU with caches off is a separate requirement.
- Stage READY is published inside `initCPU`, before proving return to scheduling,
  timer delivery, or receipt of the queued SGI. `!SIGPdisabled` is not an IRQ counter.
- A startup failure now breaks out but still announces all CPUs initialized and
  passes the full configured CPU maximum to XNU. It does not safely offline the
  failed processors. Do not treat this as a valid single-CPU fallback.
- `now + 250 * NSEC_PER_MSEC` mixes absolute ticks with nanoseconds. Convert the
  interval using XNU's time APIs. This affects diagnostic cadence.

### P1/P2: Observability, memory, and storage assumptions need bounds

- Patch 0084 copies roughly **10.4 MB of framebuffer pixels per scrolled line**
  at 1080x2460, before accounting for reads plus writes. Heavy startup logging can
  make boot appear stalled. Use a bounded in-memory text log and a low-cost display
  strategy; avoid printing from interrupt handlers on every interrupt.
- Heartbeat output proves scheduling reached that thread when visible. Its absence
  cannot distinguish a broken timer, blocked thread, failed console, or earlier hang.
- The persistent log only flushes after UFS initialization and writable-root setup.
  A failed pre-UFS boot can leave an older on-disk log. Add boot IDs, not guesses.
- LOW vs MID changes location **and alignment**. LOW base `0xb0280000` is not
  32-MiB aligned, whereas MID/HIGH are. `mkpayload.py` explicitly relies on 32-MiB
  block alignment. Audit the loader/bootstrap contract before accepting LOW.
  A crash is not proof of a physical bank boundary at `0xc0000000`.
- The supplied DTB's `/memory@80000000/reg` has **size zero**, a bootloader-fill
  placeholder. It cannot validate usable RAM. HIGH size `0x170000000` is **5.75
  GiB**, not 3.7 GiB; its interval is `[0x100000000, 0x270000000)`. Keep HIGH as the
  previously better-performing baseline, while checking runtime RAM/carveouts for
  this upgraded 12-GB unit and later a stock 8-GB unit.
- Matching UFS MMIO addresses does not establish working storage. Current
  `sweet_ufs.c` assumes an enabled bootloader host/link, LUN0 and 4096-byte blocks.
  The supplied DTB also declares UFS IOMMU streams `0xe0` and `0x4e0`; above-4-GB
  DMA and firmware SMMU state remain unverified. A 64-bit DMA capability bit alone
  does not prove address translation or access permission.
- After successful UFS initialization, inherited key/touch/USB probes run. Touch
  uses SWEET GENI/TLMM addresses and programming. Start with `sweetkeys=0
  sweettouch=0 sweetusb=0`; registered HID stubs do not prove working V60 hardware.
- Do not assume the generic cache-maintenance calls are no-ops just because another
  port had that problem. SWEET.h defines coherent CPU caches, not coherent I/O;
  inspect the actual build macros/disassembly before changing DMA maintenance.

## Execution roadmap for GPT-6.1-Sol

### Phase 0 — Freeze provenance and make checks catch the real defects

1. Work in `/home/rofikkernel/xnu/ios-timelm`. Preserve current binaries and hashes.
   Use `$HOME/work/` for new build trees, respecting the user's earlier request to
   avoid `/tmp`. Keep the already-flashed userdata image for kernel iterations.
2. Add a timer comparison to `check-adt-vs-dtb.py`: decode the timer binding, convert
   PPI to INTID, reject missing/mismatched required fields. Include a regression
   fixture proving the current timer-19 ADT fails and timer-27 passes. Also check
   payload-embedded ADT, not just a source-side file.
3. Add a small SGI encoder test against independent architectural expected values:
   CPU0 `0x01000001`, CPU1 `0x01010001`, CPU7 `0x01070001`, plus nonzero Aff2/Aff3.
4. Make artifacts identify kernel commit/hash, shim revision, ADT hash, root mode,
   CPU count, timer INTID and a unique trial ID. Repeat the ID at major milestones.

**Exit:** existing images demonstrably fail the timer check; test vectors catch
0083's SGI regression; manifest can unambiguously identify the next phone trial.

### Phase 1 — Repair interrupts and establish single-CPU RAM-disk userspace

1. Add a corrective patch after 0084, normally 0085: restore the correct SGI
   expression; remove invented GICR group writes; replace the stage cache protocol;
   restore honest startup failure behavior and tick conversion. Preserve useful
   diagnostics, but gate/rate-limit them.
2. Set timelm ADT virtual timer to 27 and diagnostic shim virtual/physical timers
   to 27/30. Correct the kernel fallback in the timelm patch series as well. Keep
   device-specific values explicit; do not silently modify the sibling SWEET port.
3. Use HIGH RAM, `cpus=1`, `rd=md0`, optional hardware disabled. Explicitly regenerate
   the ADT: `build-boot.sh` currently consumes an existing ADT and does not refresh it.
   Change its default LOW/SMP8 profile to the validated diagnostic default or require
   explicit arguments. The default build comment is not sufficient protection.
4. Confirm the running kernel reports INTID 27, increments a bounded timer IRQ
   counter, receives SGI1, and resumes a timed sleep. Record CNTFRQ_EL0 and compare
   it with the ADT's 19.2-MHz timebase. Record DAIF, CNTV_CTL/CVAL, PMR, IGRPEN1,
   redistributor enable/pending bits if timer delivery fails.
5. Use 0084's BSD trace to bracket `IOKitInitializeTime()`. Allow at least 60–90
   seconds for the current 30-second RTC wait. Do not bypass the wait merely to
   disguise broken timed scheduling. Add a no-RTC platform path later if warranted.
6. Observe `*** SWEET userspace: init running as PID 1 ***` and correctly spaced
   `SWEET init: still alive` messages for several minutes. This static RAM-disk init
   validates the user/kernel transition; it is not Apple's launchd.

**Exit:** repeatable physical single-CPU RAM-disk boot, real timer/SGI delivery,
timed sleeps functioning, no unexpected exception. Save full boot evidence.

Optional isolation: retain a provenance-verified pre-0083 kernel and produce a
timer-27-only ADT/payload variant to test the original timer hypothesis independently.
Do not obtain a moving `latest` kernel and call it the historical control.

The shim's normal payload path jumps to XNU before `test_gic()`. Its no-payload
path currently probes UFS and resets before reaching the timer test. If a standalone
interrupt diagnostic is needed, give it an explicit reachable mode that avoids UFS.
Merely building the existing empty-ramdisk image does not test its timer code.

### Phase 2 — Prove read-only UFS access, then mount the existing root

1. Keep CPU1+ offline and optional hardware disabled. Add bounded milestones before
   MMIO mapping, contiguous allocation, host takeover, each first SCSI command,
   GPT parsing, HFS detection and root mount.
2. Inventory host CAP/HCE/HCS/version/list state and DMA physical ranges. Determine
   userdata's actual LUN and logical block size using recovery or read-only SCSI
   discovery. Do not assume LUN0/4K. Read and validate GPT header/entry sizes, CRCs,
   capacity and partition bounds before trusting them.
3. Test descriptor completion and repeatable block reads before permitting writes.
   If DMA fails, investigate SMMU ownership/mapping and cache operations; do not
   reset a working host/link or alter secure-world registers speculatively.
4. Compare the on-device HFS header at userdata offset 1024 with the expected root
   image. A userdata image is a partition filesystem, not a whole-disk GPT image.
5. Only after successful read-only checks, use `rd=ufsroot0 ufsrw=1 rootrw=1` for
   iOS service operation. Retain `launchd_unsecure_cache=1` and existing bring-up
   flags. Temporary `fastboot boot` avoids flashing boot partitions, but this mode
   **can write userdata** through HFS and persistent logging.
6. Verify persistent logging's tail region lies outside the HFS volume extent and
   inside userdata before enabling it. Preserve the filesystem; reflash only if
   actual root corruption or a deliberate root change requires it.

**Exit:** correct userdata/LUN/geometry, successful reads, `BSD root: ufsroot0`,
successful HFS root mount, no DMA or bounds errors. If read-only HFS mount requires
journal recovery, distinguish that filesystem requirement from a transport failure.

### Phase 3 — Bring up Apple's iOS userland

1. Observe `/sbin/launchd` exec, dyld/shared-cache mapping, PID 1 survival and service
   spawning. Trace the first exec errno/exception rather than treating every daemon
   restart as a kernel interrupt problem.
2. Audit the existing 20H392 root only when evidence points there: executable/cache
   architecture, permissions/owners, Cryptex mount paths, shared-cache links, writable
   `/private/var`, AMFI/entitlement behavior and keybag stubs. The earlier builder
   reports a healthy 16-GiB HFS volume; this session did not independently fsck it.
3. Advance to backboardd/SpringBoard only after launchd remains stable. Check the
   presented display size versus actual 1080x2460 scanout: old V60 logs still report
   1080x2460 presentation despite notes claiming an iPhone X canvas.
4. Port V60 touch/keys/display control separately, using actual controller/panel
   data. GPU, Wi-Fi and other services are later work, not prerequisites for a
   static PID 1 or initial software-rendered GUI attempt.

**Exit:** real launchd and core services run persistently; then an observed iOS UI
frame. State clearly whether success means static init, launchd, or SpringBoard.

### Phase 4 — Reintroduce SMP, then validate variants

1. Test 2 CPUs, then the four A55 CPUs, then all eight. Check per-core timer IRQs,
   self-IPIs, cross-IPIs with acknowledgments and scheduling under load.
2. Validate MIDR/MMFR0 and 16-KiB translation support per CPU, reset entry/EL state,
   GICR affinity, timebase, shared mappings and exception state. The V60 has four
   A55 plus four A77-class cores, not SWEET's six A55 plus two A76.
3. Never publish an all-CPU initialization resource after a failed bring-up unless
   XNU's topology/scheduler state has actually been reconciled. Prefer the separately
   tested `cpus=1` image as fallback.
4. Verify live memory maps for both 12-GB and stock 8-GB boards before advertising
   shared compatibility. Keep LOW disabled until its placement/alignment issue is
   resolved experimentally.

**Exit:** repeatable SMP boot, interrupt/scheduling stress passes, then iOS userland
stability with the desired CPU count and memory variants.

## First build profiles and decision rules

After Phase 1 implementation, generate an explicit fresh HIGH ADT and use a uniquely
named artifact. Suggested RAM-disk command line:

```text
debug=0xc serial=3 cpus=1 keepsyms=1 -noprogress rd=md0
unentitled_ios_sim_launch=1 ignition_level=1 wdt_test=no_user_checkin wdt=-1
sweetfb_hz=30 startup_debug=1 sweetbeat=5 sweetkeys=0 sweettouch=0 sweetusb=0 sweetlog=0
```

Use one shell string when supplying `CMDLINE`. Retain `-enable_kprintf_spam` only
when needed for a bounded trace; ensure the chosen logging profile shows milestones.
Do not enable UFS writes in the RAM-disk baseline. A later UFS profile changes root
mode and write flags after Phase 2's read-only evidence, keeping other variables fixed.

| Last reliable milestone | Next action |
|---|---|
| CPU init / BSD buffer headers, no timed wake | Validate timer 27 and bracket RTC wait |
| `IOKitInitializeTime` entry, no exit after 60–90 s | Inspect timer delivery and wait/wakeup path |
| Timers work, `bsd_autoconf` stalls | Instrument IOKit matching/resource wait |
| UFS probe begins, host/command fails | Inspect host state, DMA/SMMU, geometry/LUN |
| UFS reads work, HFS mount fails | Inspect filesystem/journal/root format |
| HFS mounts, launchd fails | Inspect exec/dyld/cache/permissions and first exception |
| launchd works, no GUI | Inspect backboardd/SpringBoard, IOSurface/IOMFB and services |

For each trial record: artifact hash, trial ID, exact command line, elapsed time,
last successful milestone, first error, and full screen/video or a proven current
log. A screen wrap can reorder displayed lines within one boot; it does not by
itself prove multiple boots. A partial capture missing a line proves only absence
from that capture.

## Validation and implementation boundaries

Completed during this investigation:

- Existing repository integrity check passes: 84 patch files, 16 Python tools,
  13 shell scripts. This is syntax/format validation, not hardware correctness.
- Existing DTB/ADT address and affinity checks pass, while the independent timer
  decoding exposes the unchecked 19-versus-27 mismatch.
- Current kernel and two 0084 boot hashes verified; all 10 payload kernel segments
  match the local kernel. Both embedded ADTs still specify 19.
- Reviewed locally reconstructed XNU in `$HOME/work/xnu-verify`, with upstream in
  `$HOME/work/xnu-src/xnu-xnu-8796.141.3`. Reconstruct after edits rather than assuming
  these scratch trees remain current.

Next executor must run corrected semantic tests, patch application validation,
the actual macOS/XNU build and artifact inspection before hardware trials. QEMU
can help test kernel paths, but does not validate V60 interrupt wiring, firmware,
UFS/SMMU, panel or RAM carveouts. No phone was tested during this investigation.

**First implementation objective:** deliver a reviewed timer-27 / corrected-SGI
single-CPU RAM-disk diagnostic image, with artifact provenance and proof criteria.
Do not rebuild or reflash the 12-GB sparse userdata download as the first action.
