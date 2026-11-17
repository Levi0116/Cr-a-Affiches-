#!/bin/bash
# Rendu par morceaux (reprend là où il s'est arrêté), puis assemblage + version WhatsApp.
# Usage : bash tools/render-chunks.sh AUDIO 7875 out/Audio-Sound-Collection-Zeynab-Store
set -e
COMP=$1; TOTAL=$2; OUT=$3; STEP=900; DIR=out/chunks-$COMP; mkdir -p $DIR
: > $DIR/list.txt
for ((s=0; s<TOTAL; s+=STEP)); do
  e=$((s+STEP-1)); [ $e -ge $TOTAL ] && e=$((TOTAL-1))
  f=$DIR/v_$(printf %05d $s).mp4
  if [ ! -f $f ]; then
    npx remotion render src/index.tsx $COMP $f.tmp.mp4 --frames=$s-$e --muted --codec=h264 --crf=18 --concurrency=4 --log=error
    mv $f.tmp.mp4 $f
  fi
  echo "file '$(basename $f)'" >> $DIR/list.txt
  echo "chunk $s-$e ok"
done
[ -f $DIR/audio.aac ] || npx remotion render src/index.tsx $COMP $DIR/audio.aac --codec=aac --log=error
ffmpeg -y -v error -f concat -safe 0 -i $DIR/list.txt -i $DIR/audio.aac -map 0:v -map 1:a -c:v copy -c:a copy -movflags +faststart $OUT.mp4
ffmpeg -y -v error -i $OUT.mp4 -vf scale=720:1280 -c:v libx264 -crf 26 -preset medium -c:a aac -b:a 128k -movflags +faststart $OUT-WhatsApp.mp4
echo RENDER_OK
