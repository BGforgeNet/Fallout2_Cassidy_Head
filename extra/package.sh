#!/bin/bash

set -xeu -o pipefail

DAT3_VERSION="v0.11.1"
IPSDOC_VERSION="v0.3.0"
# Cassidy's English dialog, from the Unofficial Patch: lip sync reads each line's text from it.
MSG_URL="https://raw.githubusercontent.com/BGforgeNet/Fallout2_Unofficial_Patch/89775d461e36a3ba153eda3010b87735650cbb7a/data/text/english/dialog/vccasidy.msg"
# zlib level for every .dat: 6 packs in under half the time of 9, for archives about 1% larger.
DAT3_LEVEL=6
MOD_NAME="cassidy"
FFMPEG_ARGS="-c:a pcm_s16le -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1"

bin_dir="$(realpath extra)/bin"
src_dir="$(realpath sound_src/joey_bracken)"
head_dir="$(realpath head)"
dst="$(realpath sound_out)"
dst_base="$dst/joey_bracken"
out_dir="$(realpath .)"
# Versioned names, so a version bump never runs a stale download.
dat3="$bin_dir/dat3-$DAT3_VERSION"
ipsdoc="$bin_dir/ipsdoc-$IPSDOC_VERSION"
msg="$bin_dir/vccasidy.msg"

# Download once, through a temporary name, so an interrupted download is never taken for a complete one.
function fetch() {
  local url="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    wget -nv -O "$path.part" "$url"
    mv "$path.part" "$path"
  fi
}

mkdir -p "$bin_dir"
fetch "https://github.com/BGforgeNet/dat3/releases/download/$DAT3_VERSION/dat3" "$dat3"
fetch "https://github.com/BGforgeNet/ipsdoc/releases/download/$IPSDOC_VERSION/ipsdoc" "$ipsdoc"
fetch "$MSG_URL" "$msg"
chmod +x "$dat3" "$ipsdoc"

# The recordings are 48 kHz mono. The original game with sfall plays 44.1 kHz speech right, but cuts 48 kHz short.
voice_dir="$dst_base/sound/speech/casdy"
rm -rf "$dst_base"
mkdir -p "$voice_dir"

cd "$src_dir"
for wav in *; do
  # ffmpeg resamples; ipsdoc then stores each result in an ACM as it is.
  # shellcheck disable=SC2086  # We do want splitting for args.
  ffmpeg -i "$wav" -ac 1 -ar 44100 $FFMPEG_ARGS "$voice_dir/$wav"
done
cd "$voice_dir"
for wav in *.wav; do
  "$ipsdoc" convert "$wav" "${wav%.wav}.acm"
done
rm -f ./*.wav
# Lip files follow the ACMs, from their sound and their line's text.
"$ipsdoc" lip --msg "$msg" ./*.acm
"$ipsdoc" check .

# dat3 adds to an existing archive, so start from none.
rm -f "$out_dir/${MOD_NAME}_head.dat"
"$dat3" a -c "$DAT3_LEVEL" -C "$head_dir" "$out_dir/${MOD_NAME}_head.dat" '*'

for d in "$dst"/*/; do
  name="$(basename "$d")"
  rm -f "$out_dir/${MOD_NAME}_voice_$name.dat"
  "$dat3" a -c "$DAT3_LEVEL" -C "$d" "$out_dir/${MOD_NAME}_voice_$name.dat" '*'
done
