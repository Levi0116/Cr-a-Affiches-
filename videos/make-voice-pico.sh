#!/bin/bash
# Voix off gratuite (SVOX Pico, français) : bash make-voice-pico.sh voice-dji2-pico.json public/dji2/vo src/dji2-voice.json
set -e
SRC=$1; OUT=$2; DUR=$3; mkdir -p "$OUT"
TMP=$(mktemp -d)
python3 -c "import json,sys;d=json.load(open('$SRC',encoding='utf-8'));[open('$TMP/'+k+'.txt','w',encoding='utf-8').write(v) for k,v in d.items()]"
echo "{" > "$DUR"; first=1
for t in "$TMP"/*.txt; do
  n=$(basename "$t" .txt)
  pico2wave -l fr-FR -w "$TMP/$n.wav" "<speed level='120'><pitch level='96'>$(cat "$t")</pitch></speed>"
  ffmpeg -v error -y -i "$TMP/$n.wav" -af "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,highpass=f=90,equalizer=f=220:t=q:w=1:g=3,equalizer=f=3500:t=q:w=1.5:g=2,acompressor=threshold=-20dB:ratio=3:makeup=3,aecho=0.8:0.7:35:0.12,loudnorm=I=-14:TP=-1.5" -ar 44100 -b:a 160k "$OUT/$n.mp3"
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$n.mp3")
  [ $first = 1 ] || echo "," >> "$DUR"; first=0; printf '"%s": %s' "$n" "$d" >> "$DUR"
done
echo "}" >> "$DUR"; rm -rf "$TMP"; cat "$DUR"
