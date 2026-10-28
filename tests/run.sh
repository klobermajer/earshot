#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
work="$(pwd)/tests/.work"
rm -rf "$work" && mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

uname() { printf 'Darwin\n'; }
source scripts/earshot.sh
unset -f uname
LOG="$work/log"
STATE_DIR="$work/state"
MUTE="$STATE_DIR/muted-until"
mkdir -p "$STATE_DIR"
project=test event=Test kind=

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n     expected: %q\n     got:      %q\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

voices=$(printf 'en\tAva (Premium)\nen\tSamantha\nen\tEvan (Enhanced)\npl\tZosia (Enhanced)\npl\tKrzysztof\nde\tAnna\n')

check "plain drops code blocks and markdown" \
  "$(printf 'Done. See `foo.sh`:\n\n```bash\necho hi\n```\n\n- **Fixed** [link](http://x) and _more_\n' | plain)" \
  "Done. See foo.sh: - Fixed link and more"
check "plain defuses say control commands" "$(printf 'Hello [[rate 40]] there' | plain)" "Hello [rate 40] there"
check "plain defuses nested brackets" "$(printf '[]][rate 40][[]' | plain)" "[][rate 40][]"
check "plain keeps a language tag" "$(printf '[pl] Gotowe' | plain)" "[pl] Gotowe"

check "shorten keeps a short line" "$(shorten 'Done.')" "Done."
check "shorten cuts a long line for the log" \
  "$(shorten 'Login page fixed and all tests pass, should I deploy it to production now or wait?')" \
  "Login page fixed and all tests pass, should I deploy it to p…"

check "first_sentence keeps a version number" \
  "$(printf 'Version 1.2 is out. Next sentence.' | first_sentence)" "Version 1.2 is out."
check "first_sentence without punctuation keeps the text" \
  "$(printf 'No punctuation at all' | first_sentence)" "No punctuation at all"

text="[pl] Strona naprawiona."; split_language
check "split_language takes a bracketed code" "$language|$text" "pl|Strona naprawiona."
text="[EN] Done."; split_language
check "split_language lowercases the code" "$language|$text" "en|Done."
text="no tests failed"; split_language
check "split_language ignores a plain two-letter word" "$language|$text" "|no tests failed"
text="SKIP"; split_language
check "split_language leaves SKIP alone" "$language|$text" "|SKIP"

check "summary_input wraps a short message" "$(summary_input 'hello')" $'<message>\nhello\n</message>'
long=$(printf 'a%.0s' $(seq 1 2100))
wrapped=$(summary_input "$long")
check "summary_input keeps the tail of a long message" "${#wrapped}" "2022"
check "summary_input marks the cut" "$(summary_input "$long" | sed -n 2p | head -c3)" "…"
check "clip counts characters, not bytes" "$(printf 'ż%.0s' $(seq 1 400) | clip | wc -m | tr -d ' ')" "$LINE_MAX_CHARS"

unset EARSHOT_VOICE EARSHOT_VOICES
check "default voice" "$(resolve_voice)" "Ava (Premium)"
check "default voice speaks its own language" "$(resolve_voice en)" "Ava (Premium)"
check "best installed voice for another language" "$(resolve_voice pl)" "Zosia (Enhanced)"
EARSHOT_VOICES="pl:Krzysztof, de:Anna"
check "configured voice per language" "$(resolve_voice pl)" "Krzysztof"
check "configured voice for a second language" "$(resolve_voice de)" "Anna"
check "configured_voice ignores unknown language" "$(configured_voice fr)" ""
unset EARSHOT_VOICES
check "default voice when the language has no voice" "$(resolve_voice fr)" "Ava (Premium)"
check "log notes the missing language" "$(grep -c 'no voice installed for fr' "$LOG")" "1"
EARSHOT_VOICE="Nobody"
check "fallback voice when the default is not installed" "$(resolve_voice)" "Samantha"
voices=$(printf 'en\tSamantha\nen\tEvan (Enhanced)\n')
unset EARSHOT_VOICE
check "best English voice when Ava is missing" "$(resolve_voice en)" "Evan (Enhanced)"
check "fallback voice for a prompt when Ava is missing" "$(resolve_voice)" "Samantha"

unset EARSHOT_LANGUAGE
check "summary prompt follows the message language" "$(summary_prompt | grep -c 'language the message is written in')" "1"
check "summary prompt has no placeholder left" "$(summary_prompt | grep -c LANGUAGE_RULE)" "0"
EARSHOT_LANGUAGE=PL
check "summary language is lowercased" "$(summary_language)" "pl"
check "summary prompt enforces the language" "$(summary_prompt | grep -c 'code "pl", whatever language')" "1"
EARSHOT_LANGUAGE=polish
check "invalid summary language is ignored" "$(summary_language)|$(summary_prompt | grep -c 'language the message is written in')" "|1"
unset EARSHOT_LANGUAGE

check "default rate" "$(speech_rate)" "185"
EARSHOT_RATE=abc
check "invalid rate falls back" "$(speech_rate)" "185"
EARSHOT_RATE=220
check "custom rate" "$(speech_rate)" "220"
unset EARSHOT_RATE

check "flag default on" "$(flag EARSHOT_BANNERS 1 && echo on || echo off)" "on"
EARSHOT_BANNERS=0
check "flag off with 0" "$(flag EARSHOT_BANNERS 1 && echo on || echo off)" "off"
EARSHOT_BANNERS=false
check "flag off with false" "$(flag EARSHOT_BANNERS 1 && echo on || echo off)" "off"
EARSHOT_BANNERS=""
check "empty flag keeps the default" "$(flag EARSHOT_BANNERS 1 && echo on || echo off)" "on"
unset EARSHOT_BANNERS
check "mute default off" "$(muted && echo muted || echo open)" "open"
EARSHOT_MUTE=true
check "mute switch" "$(muted && echo muted || echo open)" "muted"
unset EARSHOT_MUTE

echo $(($(date +%s) + 60)) >"$MUTE"
check "timed mute" "$(muted && echo muted || echo open)" "muted"
echo $(($(date +%s) - 60)) >"$MUTE"
check "expired mute" "$(muted && echo muted || echo open)" "open"
morning=$(tomorrow_morning)
check "tomorrow morning is 8:00" "$(perl -MPOSIX -e 'print strftime("%H:%M", localtime shift)' "$morning")" "08:00"
check "tomorrow morning is the next day" "$(perl -MPOSIX -e 'print strftime("%F", localtime shift)' "$morning")" "$(perl -MPOSIX -e '@now = localtime; print strftime("%F", 0, 0, 12, $now[3] + 1, $now[4], $now[5])')"
mute_until_tomorrow
check "mute until tomorrow" "$(muted && echo muted || echo open)" "muted"
unmute
session=session-a
mute_session
check "a muted session is muted" "$(muted && echo muted || echo open)" "muted"
session=session-b
check "another session still speaks" "$(muted && echo muted || echo open)" "open"
session=session-a
unmute
check "unmute ends the session mute" "$(muted && echo muted || echo open)" "open"
session=

alert() {
  printf '%s\n' "$@" >"$work/alert-args"
  printf '%s' "$alert_choice"
  return "$alert_status"
}
say_pid= alert_choice= alert_status=$DROPDOWN_LABEL_CRASH
show_banner
check "the first mute choice is the dropdown label" "$(sed -n '/^--dropdown-label$/{n;p;}' "$work/alert-args")" "Mute 30 min"
check "the other mute choices are the actions" "$(sed -n '/^--actions$/{n;p;}' "$work/alert-args")" "Mute 4 h,Mute until tomorrow,Mute this session"
check "alerter crashing on the dropdown label mutes for 30 min" "$(tail -n1 "$LOG" | sed 's/.*: //')" "muted for 30 min"
mute_for 14400
before=$(cat "$MUTE")
show_banner
check "alerter crashing on the Unmute banner keeps the mute" "$(cat "$MUTE")" "$before"
unmute
alert_choice="Mute 4 h" alert_status=0
show_banner
check "a mute choice from the menu" "$(tail -n1 "$LOG" | sed 's/.*: //')" "muted for 240 min"
unmute
unset -f alert

STATE_DIR="$work/state-new"
check "state dir is created private to the user" "$(state_dir_ready && { stat -c %a "$STATE_DIR" 2>/dev/null || stat -f %Lp "$STATE_DIR"; })" "700"
ln -s "$work/state-new" "$work/state-link"
STATE_DIR="$work/state-link"
check "state dir refuses a symlink" "$(state_dir_ready && echo ready || echo refused)" "refused"
STATE_DIR="$work/state"

real_mic_check=$MIC_CHECK
MIC_CHECK="$work/mic-check"
export MIC_ARGS="$work/mic-args"
cat >"$MIC_CHECK" <<'EOF'
import os
import sys
open(os.environ['MIC_ARGS'], 'w').write(sys.argv[2])
if sys.argv[2]:
    print('com.apple.siri')
    sys.exit(1)
sys.exit(0)
EOF
if xcode-select -p >/dev/null 2>&1; then
  unset EARSHOT_MIC_IGNORE
  check "mic in use without an ignore list" "$(mic_in_use && echo busy || echo free)" "busy"
  check "mic check gets an empty list by default" "$(cat "$MIC_ARGS")" ""
  EARSHOT_MIC_IGNORE="com.apple.Siri, corespeechd"
  check "ignored recorder leaves the mic free" "$(mic_in_use && echo busy || echo free)" "free"
  check "mic check gets the ignore list" "$(cat "$MIC_ARGS")" "com.apple.Siri, corespeechd"
  check "log names the ignored recorder" "$(grep -c 'mic used by com.apple.siri, ignored' "$LOG")" "1"
  unset EARSHOT_MIC_IGNORE
fi
MIC_CHECK=$real_mic_check
unset MIC_ARGS

check "ignore list is split, trimmed and lowercased" \
  "$(/usr/bin/python3 -I -c "import importlib.util, sys; spec = importlib.util.spec_from_file_location('mic', sys.argv[1]); mic = importlib.util.module_from_spec(spec); spec.loader.exec_module(mic); print(sorted(mic.ignored_names(' com.apple.Siri ,corespeechd,, ')))" "$MIC_CHECK")" \
  "['com.apple.siri', 'corespeechd']"
check "mic check decides from the recorders and the ignore list" \
  "$(/usr/bin/python3 -I tests/mic-check.py "$MIC_CHECK")" \
  "$(printf '1 []\n0 []\n0 []\n0 []\n1 [com.apple.siri]\n1 [siri zoom.us]\n0 []\n0 [com.apple.siri, siri us.zoom.xos, zoom.us]')"

output=$(HOME="$work" XDG_DATA_HOME="$work" PATH=/usr/bin:/bin ./scripts/session-start.sh)
if [ "$(uname)" = Darwin ]; then
  check "session-start lists a missing optional tool" "$(grep -c 'alerter (optional' <<<"$output")" "1"
  check "session-start gives no brew hint for say" "$(grep -c 'brew install say' <<<"$output")" "0"
else
  check "session-start lists missing Piper on Linux" "$(grep -c 'Piper with a voice (required' <<<"$output")" "1"
  check "session-start gives no brew hint on Linux" "$(grep -c 'brew install' <<<"$output")" "0"
fi

uname() { printf 'Linux\n'; }
source scripts/earshot.sh
unset -f uname
LOG="$work/log"
LOCK="$work/lock"

voices=$(printf 'en\ten_US-amy-medium\nen\ten_US-lessac-high\npl\tpl_PL-darkman-low\npl\tpl_PL-gosia-medium\n')
unset EARSHOT_VOICE EARSHOT_VOICES
check "linux default voice" "$(resolve_voice)" "en_US-amy-medium"
check "linux prefers a medium voice to a low one" "$(resolve_voice pl)" "pl_PL-gosia-medium"
EARSHOT_VOICE="nobody"
check "linux falls back to the best English voice" "$(resolve_voice)" "en_US-lessac-high"
voices=$(printf 'pl\tpl_PL-gosia-medium\n')
check "linux falls back to any voice without an English one" "$(resolve_voice)" "pl_PL-gosia-medium"
unset EARSHOT_VOICE

check "linux length scale for the default rate" "$(length_scale)" "0.92"
EARSHOT_RATE=340
check "linux length scale for a faster rate" "$(length_scale)" "0.50"
unset EARSHOT_RATE

playerctl() {
  case "$1:$3" in
    -l:) printf 'spotify\nbrave.instance42\nfirefox.instance_1_9\n' ;;
    -p:status) [ "$2" = firefox.instance_1_9 ] && echo Paused || echo Playing ;;
    -p:metadata) [ "$2" = spotify ] && echo "$spotify_title" || echo "Some song" ;;
  esac
}
spotify_title="Google Meet"
check "linux pauses a playing browser by its player name" "$(pausable_app)" "brave"
spotify_title="Some song"
check "linux pauses the first playing app on the list" "$(pausable_app)" "spotify"
EARSHOT_PAUSE_APPS="firefox"
check "linux leaves a paused player alone" "$(pausable_app)" ""
unset EARSHOT_PAUSE_APPS
unset -f playerctl

STATE_DIR="$work/state"
MUTE="$STATE_DIR/muted-until"
alert() {
  printf '%s\n' "$@" >"$work/alert-args"
  return "$DROPDOWN_LABEL_CRASH"
}
show_banner
check "linux shows every mute choice as a button" "$(sed -n '/^--actions$/{n;p;}' "$work/alert-args")" "Mute 30 min,Mute until tomorrow,Mute this session"
check "linux passes no dropdown label" "$(grep -c '^--dropdown-label$' "$work/alert-args")" "0"
check "linux does not take a crash for a mute" "$(muted && echo muted || echo open)" "open"
unset -f alert

if command -v flock >/dev/null; then
  flock "$LOCK" sleep 3 &
  sleep 0.5
  LOCK_TIMEOUT=1 with_lock true
  check "linux lock timeout returns the status speak logs as dropped" "$?" "75"
  wait
fi

versions=$(
  jq -r .version .claude-plugin/plugin.json
  jq -r '.plugins[0].version' .claude-plugin/marketplace.json
  sed -n 's:.*<string>\([0-9.]*\)</string>.*:\1:p' app/Earshot.app/Contents/Info.plist
)
check "version is the same in plugin.json, marketplace.json and Info.plist" "$(sort -u <<<"$versions" | wc -l | tr -d ' ')" "1"

printf '\n%s\n' "$([ $failures -eq 0 ] && echo "all passed" || echo "$failures failed")"
exit $((failures > 0))
