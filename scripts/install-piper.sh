#!/bin/bash
set -e

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/earshot"
VOICES_URL=https://huggingface.co/rhasspy/piper-voices/resolve/main

mkdir -p "$DATA_DIR/voices"
if [ ! -x "$DATA_DIR/venv/bin/piper" ]; then
  pip=("$DATA_DIR/venv/bin/pip")
  if ! python3 -m venv --clear "$DATA_DIR/venv" 2>/dev/null; then
    python3 -m venv --clear --without-pip "$DATA_DIR/venv"
    pip=(python3 -m pip --python "$DATA_DIR/venv/bin/python")
  fi
  "${pip[@]}" install -q piper-tts
fi

voices=("$@")
[ $# -gt 0 ] || voices=(en_US-amy-medium)

for voice in "${voices[@]}"; do
  locale=${voice%%-*} speaker=${voice#*-} quality=${voice##*-}
  speaker=${speaker%-*}
  for ext in onnx onnx.json; do
    [ -f "$DATA_DIR/voices/$voice.$ext" ] && continue
    curl -fL -o "$DATA_DIR/voices/$voice.$ext.part" "$VOICES_URL/${locale%%_*}/$locale/$speaker/$quality/$voice.$ext"
    mv "$DATA_DIR/voices/$voice.$ext.part" "$DATA_DIR/voices/$voice.$ext"
  done
done

ls "$DATA_DIR/voices"
