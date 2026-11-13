#!/bin/bash
# loops a sample file out over srt as a listener. mediaconnect connects in and pulls it.
# if the download fails we fall back to a generated test pattern so there's always a signal.
set -u

PORT="${SRT_PORT:-9000}"
LAT="${SRT_LATENCY_US:-2000000}"
URL="${SOURCE_VIDEO_URL:-}"
OUT="srt://0.0.0.0:${PORT}?mode=listener&latency=${LAT}&transtype=live"

mkdir -p /opt/source

if [ -n "$URL" ] && curl -fsSL --retry 3 -o /opt/source/sample.mp4 "$URL"; then
  # copy the video (cheap), re-encode audio to 48k aac. map both so the ts always has audio.
  exec ffmpeg -hide_banner -re -fflags +genpts -stream_loop -1 \
    -i /opt/source/sample.mp4 \
    -map 0:v:0 -map "0:a:0?" \
    -c:v copy -c:a aac -b:a 128k -ar 48000 -ac 2 \
    -f mpegts "$OUT"
else
  # no sample, just make colour bars and a tone
  exec ffmpeg -hide_banner -re \
    -f lavfi -i "testsrc2=size=1280x720:rate=30" \
    -f lavfi -i "sine=frequency=1000:sample_rate=48000" \
    -c:v libx264 -preset veryfast -b:v 3M -g 60 -keyint_min 60 -pix_fmt yuv420p \
    -c:a aac -b:a 128k -ar 48000 -ac 2 -f mpegts "$OUT"
fi
