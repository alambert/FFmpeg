#!/usr/bin/env bash

set -e
set -x

out=`mktemp -d`

cd "${out}"

# manifest: http://localhost:8080/manifest.mpd
# players:
# - http://reference.dashif.org/dash.js/v3.0.1/samples/dash-if-reference-player/index.html?mpd=http://localhost:8080/manifest.mpd
# - https://shaka-player-demo.appspot.com/demo/#audiolang=en-US;textlang=en-US;uilang=en-US;asset=http://localhost:8080/manifest.mpd;panel=HOME;build=uncompiled
# - VLC

# originally, we used:
# python3 -m http.server --directory . 8080 &
# but we need CORS, so follow https://stackoverflow.com/a/28632834:
# npm install http-server
# make sure you use `-c-1` to disable caching, or you'll serve old manifests :-(
~/node_modules/http-server/bin/http-server . -p 8080 --cors -c-1 &

httpd_pid=$!

# On Mac:
# https://trac.ffmpeg.org/wiki/CompilationGuide/macOS#CompilingFFmpegyourself
# git clone https://git.ffmpeg.org/ffmpeg.git
# ./configure --enable-gpl --enable-libx264 --enable-filter=drawtext  --enable-libfreetype
# make

# On Ubuntu:
# git clone https://git.ffmpeg.org/ffmpeg.git
# sudo apt install gcc yasm libfreetype6-dev pkg-config libx264-dev ttf-dejavu
# ./configure --enable-gpl --enable-libx264 --enable-filter=drawtext  --enable-libfreetype
~/w/ffmpeg/ffmpeg \
  -hide_banner \
  -re \
  -f lavfi \
  -i "testsrc2=size=1280x720:rate=30,format=yuv420p" \
  -f lavfi \
  -i "sine=frequency=1000:sample_rate=44100" \
  -vf "drawtext=fontfile=/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansMono.ttf:text='%{gmtime}Z %{n}':box=1:fontcolor=black:fontsize=24:x=(w-tw)/2:y=(h-th)/2" \
  -c:v libx264 \
  -preset:v ultrafast \
  -profile:v high \
  -b:v 1000k \
  -g 60 \
  -refs 3 \
  -bf 0 \
  -sc_threshold 0 \
  -c:a aac \
  -b:a 128k  \
  -f dash \
  -seg_duration 2 \
  -window_size 150 \
  -extra_window_size 60 \
  -remove_at_exit 1 \
  -use_timeline 0 \
  -init_seg_name 'init-stream$RepresentationID$.mp4' \
  -media_seg_name 'chunk-stream$RepresentationID$-$Number$.mp4' \
  manifest.mpd &

# For Mac:
#   -vf "drawtext=fontfile=/Library/Fonts/Roboto-Thin.ttf:text='%{gmtime}Z %{n}':box=1:fontcolor=black:fontsize=24:x=(w-tw)/2:y=(h-th)/2" \

ffmpeg_pid=$!

trap 'kill "${httpd_pid}" "${ffmpeg_pid}"; exit' INT
wait "${httpd_pid}" "${ffmpeg_pid}"
