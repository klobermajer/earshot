#!/bin/bash

[ -n "$EARSHOT_CHILD" ] && exit 0

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log="$HOME/Library/Logs/earshot.log"
keep_lines=2000

if [ -f "$log" ] && [ "$(wc -l <"$log")" -gt $((keep_lines * 2)) ]; then
  tail -n "$keep_lines" "$log" >"$log.trim" && mv "$log.trim" "$log"
fi

missing=()

[ "$(uname)" = Darwin ] || missing+=("macOS: earshot only works on macOS and stays silent here")

for tool in say lockf perl; do
  command -v "$tool" >/dev/null || missing+=("$tool (required, ships with macOS): not on PATH")
done

command -v jq >/dev/null || missing+=("jq (required, nothing is spoken without it): brew install jq")

command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] \
  || missing+=("claude (required, writes the summaries): not on PATH")

command -v alerter >/dev/null \
  || missing+=("alerter (optional, banner with Mute button): brew install vjeantet/tap/alerter")

command -v media-control >/dev/null \
  || missing+=("media-control (optional, pauses music while speaking): brew install media-control")

xcode-select -p >/dev/null 2>&1 \
  || missing+=("Command Line Tools (optional, detects calls so nothing is spoken during them): xcode-select --install")

[ ${#missing[@]} -eq 0 ] && exit 0

printf 'The earshot plugin (spoken summaries of finished turns, permission prompts and questions) found tools missing on this machine. Do not mention this unprompted. If the user asks why nothing is spoken, why there is no banner or Mute button, why music keeps playing, or why lines are spoken during calls, tell them what is missing and point them to the Requirements section of %s/README.md.\n' "$root"
printf '  - %s\n' "${missing[@]}"
