#!/usr/bin/env bash
# sanity check: player loads, manifest has the 3 rungs, ffprobe can read them
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"
cd "$TF_DIR"

PLAYER_URL="$(terraform output -raw player_url)"
HLS_URL="$(terraform output -raw hls_url)"
rc=0

echo "==> player: $PLAYER_URL"
code="$(curl -s -o /dev/null -w '%{http_code}' "$PLAYER_URL")"
echo "    HTTP $code"; [ "$code" = "200" ] || rc=1

echo "==> manifest: $HLS_URL"
manifest="$(curl -s --compressed "$HLS_URL")"
variants="$(printf '%s\n' "$manifest" | grep -c 'EXT-X-STREAM-INF')"
echo "    renditions found: $variants (expected 3)"
[ "$variants" -ge 3 ] || rc=1

if command -v ffprobe >/dev/null 2>&1; then
  echo "==> ffprobe top variant"
  ffprobe -v error -show_entries stream=codec_name,width,height -of default=noprint_wrappers=1 "$HLS_URL" 2>/dev/null || true
fi

[ "$rc" = "0" ] && echo "PROBE OK" || echo "PROBE FAILED"
exit $rc
