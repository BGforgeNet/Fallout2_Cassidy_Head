#!/bin/bash

set -xeu -o pipefail

extra_dir="$(realpath extra)"
bin_dir="$extra_dir/bin"
dat2a="wine $bin_dir/dat2.exe a -1"
file_list="/tmp/file.list"
wav2lip="wine $bin_dir/wav2lip.exe"
head_dir="$(realpath head)"
src="$(realpath sound_src)"
dst="$(realpath sound_out)"

cd "$src"
for actor in $(ls); do
  cd "$actor"
  rm -rf "$dst/$actor" "$dst/${actor}_hq"
  mkdir -p "$dst/$actor/sound/speech/casdy" "$dst/${actor}_hq/sound/speech/casdy"
  for wav in $(ls); do
    # I assume ffmpeg is better at resampling than snd2acm
    ffmpeg -i "$wav" -ac 2 -ar 44100 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 "$dst/${actor}_hq/sound/speech/casdy/$wav"
    ffmpeg -i "$wav" -ac 2 -ar 22050 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 "$dst/${actor}/sound/speech/casdy/$wav"
  done
  cd "$dst/${actor}/sound/speech/casdy"
  cp "$bin_dir/snd2acm.exe" .
  for wav in $(ls *.wav); do
    $wav2lip -i "$wav"
  done
  rm -f *.wav
  cd "$dst/${actor}_hq/sound/speech/casdy"
  rm -f snd2acm.exe
  for wav in $(ls *.wav); do
    $wav2lip -i "$wav" -noACM
    acm="$(echo $wav | sed 's|\.wav|.acm|')"
    ipsdoc "$wav" "$acm"
  done
  rm -f *.wav
done

cd "$head_dir"
find . -type f | sed -e 's|^\.\/||' -e 's|\/|\\|g' | sort > "$file_list"
rm -f "../../cassidy_head.dat"
$dat2a "../../cassidy_head.dat" @"$file_list" 2>&1 | grep -v "wine: Read access denied for device"
cd ..

cd "$dst"
for d in $(ls); do
  cd "$d"
  find . -type f | sed -e 's|^\.\/||' -e 's|\/|\\|g' | sort > "$file_list"
  rm -f "../../cassidy_voice_$d.dat"
  $dat2a "../../cassidy_voice_$d.dat" @"$file_list" 2>&1 | grep -v "wine: Read access denied for device"
  cd ..
done
