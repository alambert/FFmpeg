#!/usr/bin/env bash

set -e

scenario=$1
shift
port=$1
shift

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
# sudo apt install npm
# npm install http-server
# make sure you use `-c-1` to disable caching, or you'll serve old manifests :-(
~/node_modules/http-server/bin/http-server . -p "${port}" --cors -c-1 &

httpd_pid=$!

# On Mac:
# https://trac.ffmpeg.org/wiki/CompilationGuide/macOS#CompilingFFmpegyourself
# git clone https://github.com/alambert/FFmpeg
# ./configure --enable-gpl --enable-libx264 --enable-filter=drawtext  --enable-libfreetype
# make

# On Ubuntu:
# git clone https://github.com/alambert/FFmpeg
# sudo apt install gcc yasm libfreetype6-dev pkg-config libx264-dev ttf-dejavu
# ./configure --enable-gpl --enable-libx264 --enable-filter=drawtext  --enable-libfreetype

case "${scenario}" in
standard)
  scenario_args='-use_timeline 0 -init_seg_name init-stream$RepresentationID$.mp4 -media_seg_name chunk-stream$RepresentationID$-$Number$.mp4'
  ;;
timeline-crash)
  scenario_args='-use_timeline 1 -init_seg_name init-stream$RepresentationID$.mp4 -media_seg_name chunk-stream$RepresentationID$-$Number$.mp4'
  ;;
relative-path)
  mkdir foobar
  scenario_args='-use_timeline 0 -init_seg_name foobar/../init-stream$RepresentationID$.mp4 -media_seg_name foobar/../chunk-stream$RepresentationID$-$Number$.mp4'
  ;;
relative-path-2)
  mkdir foobar
  cd foobar
  scenario_args='-use_timeline 0 -init_seg_name ../init-stream$RepresentationID$.mp4 -media_seg_name ../chunk-stream$RepresentationID$-$Number$.mp4'
  ;;
*)
  echo "${0}: unknown scenario ${scenario}"
  exit 1
  ;;
esac

#fontfile="/Library/Fonts/Roboto-Thin.ttf"
fontfile="/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansMono.ttf"

~/ffmpeg/ffmpeg \
  -hide_banner \
  -re \
  -f lavfi \
  -i "testsrc2=size=1280x720:rate=30,format=yuv420p" \
  -f lavfi \
  -i "sine=frequency=1000:sample_rate=44100" \
  -vf "drawtext=fontfile=${fontfile}:text='%{gmtime}Z %{n}':box=1:fontcolor=black:fontsize=64:x=(w-tw)/2:y=(h-th)/2" \
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
  ${scenario_args} \
  manifest.mpd &

ffmpeg_pid=$!

trap 'kill "${httpd_pid}" "${ffmpeg_pid}"; exit' INT
wait "${httpd_pid}" "${ffmpeg_pid}"
