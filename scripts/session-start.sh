#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/earshot.sh"

keep_lines=2000

if [ -f "$LOG" ] && [ "$(wc -l <"$LOG")" -gt $((keep_lines * 2)) ]; then
  tail -n "$keep_lines" "$LOG" >"$LOG.trim" && mv "$LOG.trim" "$LOG"
fi

missing=()

case $PLATFORM in
  Darwin)
    for tool in say lockf perl; do
      command -v "$tool" >/dev/null || missing+=("$tool (required, ships with macOS): not on PATH")
    done

    command -v jq >/dev/null || missing+=("jq (required, nothing is spoken without it): brew install jq")

    command -v alerter >/dev/null \
      || missing+=("alerter (optional, banner with Mute button): brew install vjeantet/tap/alerter")

    command -v media-control >/dev/null \
      || missing+=("media-control (optional, pauses music while speaking): brew install media-control")

    xcode-select -p >/dev/null 2>&1 \
      || missing+=("Command Line Tools (optional, detects calls so nothing is spoken during them): xcode-select --install")
    ;;
  Linux)
    [ -x "$PIPER" ] && compgen -G "$VOICES_DIR/*.onnx" >/dev/null \
      || missing+=("Piper with a voice (required, speaks the lines): bash $PLUGIN_ROOT/scripts/install-piper.sh")

    for tool in paplay flock jq perl; do
      command -v "$tool" >/dev/null || missing+=("$tool (required, nothing is spoken without it): sudo apt install pulseaudio-utils util-linux jq perl")
    done

    python3 -c 'import gi' 2>/dev/null \
      || missing+=("python3-gi (optional, banner with Mute button): sudo apt install python3-gi")

    command -v playerctl >/dev/null \
      || missing+=("playerctl (optional, pauses music while speaking): sudo apt install playerctl")

    command -v pw-dump >/dev/null \
      || missing+=("pw-dump (optional, detects calls so nothing is spoken during them): sudo apt install pipewire-bin")
    ;;
  *)
    missing+=("macOS or Linux: earshot only works on these and stays silent here")
    ;;
esac

command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] \
  || missing+=("claude (required, writes the summaries): not on PATH")

[ ${#missing[@]} -eq 0 ] && exit 0

printf 'The earshot plugin (spoken summaries of finished turns, permission prompts and questions) found tools missing on this machine. Do not mention this unprompted. If the user asks why nothing is spoken, why there is no banner or Mute button, why music keeps playing, or why lines are spoken during calls, tell them what is missing and point them to the Requirements section of %s/README.md.\n' "$PLUGIN_ROOT"
printf '  - %s\n' "${missing[@]}"
