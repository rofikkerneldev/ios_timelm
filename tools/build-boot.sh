#!/bin/bash
# Build a verified timelm boot image. Default: HIGH RAM, one CPU, RAM-disk init.
# Usage: PROFILE=rd|ufs-ro|ufs-rw tools/build-boot.sh [high] [output.img]
# Optional: KERNEL=path ADT=path CMDLINE='...' TRIAL=id JOBS=56 BUILD=directory
# Building writes local artifacts only. Booting a ufs-rw profile writes userdata.
set -euo pipefail
cd "$(dirname "$0")/.."

MEM="${1:-high}"
PROFILE="${PROFILE:-rd}"
TRIAL="${TRIAL:-0085-$PROFILE-$(date -u +%Y%m%dT%H%M%SZ)}"
[[ "$TRIAL" =~ ^[a-zA-Z0-9_-]{1,63}$ ]] || { echo 'invalid TRIAL identifier' >&2; exit 1; }
NAME="${2:-timelm-$TRIAL-c1.img}"
KERNEL="${KERNEL:-xnu/out/kernel.development.sweet}"
BUILD="${BUILD:-$HOME/work/timelm-build/$TRIAL}"
mkdir -p "$BUILD"

[ -f "$KERNEL" ] || { echo "missing $KERNEL" >&2; exit 1; }
if [ -z "${ADT:-}" ]; then
    [ "$MEM" = high ] || { echo 'Use explicit ADT= for experimental RAM windows' >&2; exit 1; }
    ADT="$BUILD/timelm-high.adt"
    python3 tools/mkadt.py "$ADT" --mem high
fi
python3 tools/check-adt-vs-dtb.py dtb/boot_unpacked/dtb "$ADT"

# Always rebuild init, so assembly edits cannot be hidden by a stale file.
CLANG="${CLANG:-$HOME/tools/llvm-bin/clang}"
"$CLANG" --target=aarch64-apple-ios16.0 -c tools/sweet-init.S -o "$BUILD/sweet-init.o"
python3 tools/mkinit.py "$BUILD/sweet-init.o" "$BUILD/sweet-init"

case "$PROFILE" in
    rd) ROOT_ARGS='rd=md0' ;;
    ufs-ro) ROOT_ARGS='rd=ufsroot0 ufsrw=0 rootrw=0' ;;
    ufs-rw) ROOT_ARGS='rd=ufsroot0 ufsrw=1 rootrw=1 launchd_unsecure_cache=1' ;;
    *) echo 'PROFILE must be rd, ufs-ro, or ufs-rw' >&2; exit 1 ;;
esac
CMDLINE="${CMDLINE:-debug=0xc serial=3 cpus=1 keepsyms=1 -enable_kprintf_spam -noprogress $ROOT_ARGS unentitled_ios_sim_launch=1 ignition_level=1 wdt_test=no_user_checkin wdt=-1 sweetfb_hz=30 startup_debug=0 sweetbeat=5 sweetkeys=0 sweettouch=0 sweetusb=0 sweetlog=0}"
CMDLINE="$CMDLINE timelm_trial=$TRIAL"
python3 tools/mkpayload.py "$KERNEL" "$ADT" "$BUILD/payload.bin" \
    --ramdisk "$BUILD/sweet-init" --cmdline "$CMDLINE"

(cd shim && JOBS="${JOBS:-56}" ./build.sh "$BUILD/payload.bin")
case "$NAME" in
    /*) OUT="$NAME" ;;
    *) OUT="shim/out/$NAME" ;;
esac
mkdir -p "$(dirname "$OUT")"
cp shim/out/shim-boot.img "$OUT"
python3 tools/unpack_bootv2.py "$OUT" "$BUILD/unpacked" >/dev/null
cmp "$BUILD/unpacked/ramdisk" "$BUILD/payload.bin"
python3 tools/inspect_boot.py "$OUT" --kernel "$KERNEL" --dtb dtb/boot_unpacked/dtb \
    --trial "$TRIAL" --manifest "$OUT.json"
sha256sum "$OUT" | tee "$OUT.sha256"
