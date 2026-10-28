STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/earshot"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/earshot/earshot.log"
LOCK="$STATE_DIR/lock"
MUTE="$STATE_DIR/muted-until"
SPEECH_FILE="$STATE_DIR/speech"
MUTE_ACTIONS="Mute 30 min,Mute until tomorrow,Mute this session"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/earshot"
PIPER="$DATA_DIR/venv/bin/piper"
VOICES_DIR="$DATA_DIR/voices"
BANNER_HELPER="$PLUGIN_ROOT/scripts/linux-banner.py"
ICON="$PLUGIN_ROOT/assets/icon.svg"
DEFAULT_VOICE=en_US-amy-medium
FALLBACK_VOICE=
VOICE_QUALITY='-high$;-medium$;-low$'
PIPER_WORDS_PER_MINUTE=170
DEFAULT_PAUSE_APPS="spotify,brave,chromium,firefox,vlc"
SPEECH_COMMAND=paplay
REQUIRED_TOOLS=("$PIPER" paplay flock jq perl)

playing_apps() {
  command -v playerctl >/dev/null || return
  local player
  for player in $(playerctl -l 2>/dev/null); do
    [ "$(playerctl -p "$player" status 2>/dev/null)" = Playing ] || continue
    playerctl -p "$player" metadata title 2>/dev/null | grep -Eqi "$CALL_TITLES" && continue
    printf '%s\n' "${player%%.*}"
  done
}

pause_app() {
  playerctl -p "$1" pause
}

resume_paused_app() {
  [ -n "$paused_app" ] || return
  [ "$(playerctl -p "$paused_app" status 2>/dev/null)" = Paused ] && playerctl -p "$paused_app" play
}

mic_check_available() {
  command -v pw-dump >/dev/null
}

alert() {
  python3 -I "$BANNER_HELPER" --icon "$ICON" "$@"
}

banner_available() {
  python3 -c 'import gi' 2>/dev/null
}

plain_banner() {
  notify-send --app-name Earshot --icon "$ICON" "$1" "$2" 2>>"$LOG"
}

remove_banner() {
  :
}

mute_menu() {
  options+=(--actions "$MUTE_ACTIONS")
}

length_scale() {
  awk -v base="$PIPER_WORDS_PER_MINUTE" -v rate="$(speech_rate)" 'BEGIN { printf "%.2f", base / rate }'
}

prepare_speech() {
  printf '%s' "$1" | "$PIPER" -m "$VOICES_DIR/$voice.onnx" --length-scale "$(length_scale)" --output-raw >"$SPEECH_FILE" 2>/dev/null
  [ -s "$SPEECH_FILE" ] && return
  log "piper produced no audio for $voice"
  return 1
}

start_speech() {
  exec 8<"$SPEECH_FILE"
  rm -f "$SPEECH_FILE"
  paplay --raw --rate="$(jq -r '.audio.sample_rate' "$VOICES_DIR/$voice.onnx.json")" --channels=1 --format=s16le <&8 &
  say_pid=$!
  exec 8<&-
}

list_voices() {
  local model name
  for model in "$VOICES_DIR"/*.onnx; do
    [ -f "$model.json" ] || continue
    name=$(basename "$model" .onnx)
    printf '%s\t%s\n' "${name%%_*}" "$name"
  done
}

fallback_voice() {
  local candidate
  candidate=$(best_voice en)
  printf '%s' "${candidate:-$(head -n1 <<<"$voices" | cut -f2)}"
}

with_lock() {
  flock -o -E 75 -w "$LOCK_TIMEOUT" "$LOCK" "$@"
}
