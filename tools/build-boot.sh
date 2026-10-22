#!/bin/bash
# Build a bootable LG V60 (timelm) image: XNU kernel + ADT + RAM disk init.
#
# Usage: tools/build-boot.sh [high|low] [output name]
#
#   high  kernel RAM 0x100000000 + 0x170000000 (upper DDR bank, 3.7 GiB)
#   low   kernel RAM 0xb0280000 + 0x3fd80000 (low bank, behind the phone's
#         ramoops at 0xb0000000 and below the top-of-bank pools)
#
# The kernel comes from xnu/out/kernel.development.sweet (see
# tools/fetch-kernel.sh), the ADT from tools/mkadt.py, the RAM disk from
# tools/sweet-init.S (mockfs serves it as /sbin/launchd).
#
# The result is a boot image for "fastboot boot" only: it never writes to
# any partition.
set -euo pipefail
cd "$(dirname "$0")/.."

MEM="${1:-low}"
NAME="${2:-shim-boot-timelm-$MEM-rd.img}"
KERNEL="xnu/out/kernel.development.sweet"
BUILD=/tmp/opencode/timelm-build

case "$MEM" in
	high) ADT="${ADT:-shim/out/timelm.adt}" ;;
	low)  ADT="${ADT:-shim/out/timelm-low.adt}" ;;
	*)    ADT="${ADT:-shim/out/timelm-$MEM.adt}" ;;
esac

[ -f "$KERNEL" ] || { echo "missing $KERNEL (run tools/fetch-kernel.sh)" >&2; exit 1; }

mkdir -p "$BUILD"

# RAM disk init: a static arm64 Mach-O that the kernel's mockfs serves as
# /sbin/launchd, so the kernel boots without an iOS root on the phone.
if [ ! -f "$BUILD/sweet-init" ]; then
	CLANG="${CLANG:-$HOME/tools/llvm-bin/clang}"
	"$CLANG" --target=aarch64-apple-ios16.0 -c tools/sweet-init.S -o "$BUILD/sweet-init.o"
	python3 tools/mkinit.py "$BUILD/sweet-init.o" "$BUILD/sweet-init"
fi

CMDLINE="${CMDLINE:-debug=0xc serial=3 cpus=8 keepsyms=1 -enable_kprintf_spam -noprogress rd=md0 unentitled_ios_sim_launch=1 ignition_level=1 wdt_test=no_user_checkin wdt=-1 sweetfb_hz=30}"

python3 tools/mkpayload.py "$KERNEL" "$ADT" "$BUILD/payload-$MEM.bin" \
	--ramdisk "$BUILD/sweet-init" --cmdline "$CMDLINE"

(cd shim && ./build.sh "$BUILD/payload-$MEM.bin")
case "$NAME" in
	/*) OUT="$NAME" ;;
	*)  OUT="shim/out/$NAME" ;;
esac
mkdir -p "$(dirname "$OUT")"
cp shim/out/shim-boot.img "$OUT"

# Verify the image carries exactly the payload we just built.
rm -rf "$BUILD/verify-$MEM"
python3 tools/unpack_bootv2.py "$OUT" "$BUILD/verify-$MEM" >/dev/null
cmp "$BUILD/verify-$MEM/ramdisk" "$BUILD/payload-$MEM.bin"

echo "$OUT  $(stat -c%s "$OUT") bytes  (ram $MEM)"
sha256sum "$OUT"
