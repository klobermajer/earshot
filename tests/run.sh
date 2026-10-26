#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
work="$(pwd)/tests/.work"
rm -rf "$work" && mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

source scripts/earshot.sh
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
check "summary_input marks the cut" "$(summary_input "$long" | sed -n 2p | cut -c1-1)" "…"

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

output=$(HOME="$work" PATH=/usr/bin:/bin ./scripts/session-start.sh)
check "session-start lists a missing optional tool" "$(grep -c 'alerter (optional' <<<"$output")" "1"
check "session-start gives no brew hint for say" "$(grep -c 'brew install say' <<<"$output")" "0"

versions=$(
  jq -r .version .claude-plugin/plugin.json
  jq -r '.plugins[0].version' .claude-plugin/marketplace.json
  sed -n 's:.*<string>\([0-9.]*\)</string>.*:\1:p' app/Earshot.app/Contents/Info.plist
)
check "version is the same in plugin.json, marketplace.json and Info.plist" "$(sort -u <<<"$versions" | wc -l | tr -d ' ')" "1"

printf '\n%s\n' "$([ $failures -eq 0 ] && echo "all passed" || echo "$failures failed")"
exit $((failures > 0))
