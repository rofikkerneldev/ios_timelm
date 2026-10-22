#!/bin/bash
# Fetch the latest published XNU kernel into xnu/out/.
#
# The publish workflow attaches every successful xnu build to the rolling
# GitHub release "kernel-latest", so the asset URL is stable and needs no
# token:
#   https://github.com/rofikkerneldev/ios_timelm/releases/download/kernel-latest/kernel.development.sweet
#
# Usage: tools/fetch-kernel.sh [URL]
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="https://github.com/rofikkerneldev/ios_timelm/releases/download/kernel-latest"
URL="${1:-$BASE/kernel.development.sweet}"

mkdir -p xnu/out
echo "GET $URL"
curl -fsSL "$URL" -o xnu/out/kernel.development.sweet
ls -l xnu/out/kernel.development.sweet
sha256sum xnu/out/kernel.development.sweet

# The release also carries the SHA256SUMS file the CI wrote; check it when
# it is reachable.
if curl -fsSL "$BASE/SHA256SUMS" -o /tmp/xnu-sha256sums 2>/dev/null; then
	echo "--- SHA256SUMS ---"
	cat /tmp/xnu-sha256sums
	if grep -q "$(sha256sum xnu/out/kernel.development.sweet | cut -d' ' -f1)" /tmp/xnu-sha256sums; then
		echo "checksum OK"
	else
		echo "checksum MISMATCH" >&2
		exit 1
	fi
fi
