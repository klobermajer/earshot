# earshot

[![tests](https://github.com/klobermajer/earshot/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/klobermajer/earshot/actions/workflows/tests.yml)

Keeps Claude Code within earshot: hear what it is doing without watching the terminal.

- **When a turn ends**, a one-sentence summary of Claude's last message is read aloud, starting
  with the project name: *"my-app: Review finished, two issues need your decision."*
- **When Claude needs you** — a permission prompt or a question — the prompt itself is read out:
  *"my-app: Claude needs your permission to use Bash."*
- **When Claude is only waiting for its own background agents**, nothing is said. You hear the
  result when they finish.
- **When you are on a call**, nothing is said. The line appears as a banner instead (see
  [Calls and muting](#calls-and-muting)).

While a line is spoken, a banner shows it with a **Mute 30 min** button; closing the banner stops
the line. The banner goes away when the line ends.

Several sessions take turns instead of talking over each other. Music playing in Spotify, Music, Podcasts
or a video in Chrome or Safari is paused while a line is spoken and resumed afterwards (needs
`media-control`, see below).

## Requirements

- **macOS.** Speech uses the built-in `say`; `lockf` and `perl` ship with macOS.
- **`jq`.** Included in macOS 15 and later; otherwise `brew install jq`.
- **Claude Code, signed in.** The summary is written by `claude -p --model haiku` on your own
  account.
- **`media-control`, optional.** Only needed for pausing music: `brew install media-control`.
  Without it, lines are spoken over whatever is playing.
- **`alerter`, optional.** Needed for the banner buttons: `brew install vjeantet/tap/alerter`.
  Without it, a call gets a plain banner with no buttons, and spoken lines get no banner.
- **Command Line Tools, optional.** Call detection runs a short check with the system
  `python3`, which needs them (`xcode-select --install`). It asks CoreAudio which processes
  record, an API that exists since macOS 14.2; on older systems, and without the tools, lines
  are spoken during calls as before.

Nothing is shown when one of these is missing; the plugin just does less. When Claude Code
starts, a quick check hands the list of missing tools to Claude as context, so asking it why
nothing is spoken, or why there is no banner, gets a direct answer with the install command.

### On Linux

Earshot works the same on a Linux desktop with PipeWire; it is tested on Ubuntu 26.04 with GNOME.
The macOS tools are replaced by:

- **Piper** instead of `say`, a neural voice that runs offline. Install it with a voice:
  `bash scripts/install-piper.sh` puts Piper and `en_US-amy-medium` into
  `~/.local/share/earshot`; name more voices to add them, e.g.
  `bash scripts/install-piper.sh pl_PL-gosia-medium`. The voices, with samples, are listed at
  https://rhasspy.github.io/piper-samples/. The script needs `python3-venv` or `python3-pip`.
- **`paplay`, `flock`, `jq` and `perl`**, all on a standard Ubuntu desktop.
- **`python3-gi`, optional.** Needed for the banner buttons, shown by `scripts/linux-banner.py`.
  Without it, a call gets a plain `notify-send` banner, and spoken lines get no banner.
- **`playerctl`, optional.** Only needed for pausing music: `sudo apt install playerctl`.
- **`pw-dump`, optional.** Call detection reads PipeWire's recording streams; it ships with
  PipeWire (`pipewire-bin`).

The settings below work the same, with Linux values: `EARSHOT_VOICE` and `EARSHOT_VOICES` take
Piper voice names (default `en_US-amy-medium`; the best installed voice for a language is the
`-high` one, then `-medium`, then `-low`), `EARSHOT_PAUSE_APPS` takes the player names
`playerctl -l` shows, without the `.instance…` part (default `spotify,brave,chromium,firefox,vlc`),
and `EARSHOT_MIC_IGNORE` takes the process names `mic-in-use.py --list` shows. The log is
`~/.local/state/earshot/earshot.log`.

## Install

```
/plugin marketplace add klobermajer/earshot
/plugin install earshot@earshot
```

Run `/reload-plugins` or restart Claude Code afterwards. To try a local checkout, add the
directory instead: `/plugin marketplace add ~/path/to/earshot`.

## Updates

Pull a new version by hand:

```
/plugin marketplace update earshot
/reload-plugins
```

Or let Claude Code pull it at every start, by adding `autoUpdate` to the marketplace entry in
`~/.claude/settings.json`:

```json
"extraKnownMarketplaces": {
  "earshot": {
    "source": { "source": "github", "repo": "klobermajer/earshot" },
    "autoUpdate": true
  }
}
```

Keep the `source` that `/plugin marketplace add` wrote there; only `autoUpdate` is new.
`/plugin marketplace remove earshot` deletes the whole entry, `autoUpdate` included, so add
it again after re-adding the marketplace.

## Settings

Set these in the `env` block of `~/.claude/settings.json`, then restart Claude Code (a change
in `env` does not reach hooks in a running session):

```json
{
  "env": {
    "EARSHOT_VOICE": "Zoe (Premium)",
    "EARSHOT_RATE": "200"
  }
}
```

| Variable           | Default    | Meaning                                         |
|--------------------|------------|-------------------------------------------------|
| `EARSHOT_VOICE` | `Ava (Premium)` | Your main voice, any listed by `say -v '?'`; see [Languages](#languages) for what happens when it is not installed |
| `EARSHOT_VOICES` | none      | Voices for other languages, e.g. `pl:Zosia (Enhanced),de:Anna` |
| `EARSHOT_RATE`  | `185`      | Words per minute                                |
| `EARSHOT_LANGUAGE` | none    | Two-letter code, e.g. `pl`: summaries are always written in this language |
| `EARSHOT_PAUSE_APPS` | `com.spotify.client,com.apple.Music,com.apple.podcasts,com.google.Chrome,com.apple.Safari` | Comma-separated bundle IDs whose playback is paused while speaking |
| `EARSHOT_MIC_IGNORE` | none | Comma-separated bundle IDs or process names whose recording does not count as a call, e.g. `com.apple.Siri,corespeechd` |
| `EARSHOT_MUTE` | `0` | `1` never speaks; lines only appear as banners, as during a call |
| `EARSHOT_BANNERS` | `1` | `0` shows no banners at all, spoken or not |
| `EARSHOT_MEDIA` | `1` | `0` never pauses music or videos |

The switches take `1`/`0`, `true`/`false`, `on`/`off` or `yes`/`no`.

### Languages

A summary is spoken in the language Claude answered in, or always in `EARSHOT_LANGUAGE` when
that is set, with the summary translated as needed. The voice for it is, in this order:

1. the one set for that language in `EARSHOT_VOICES`;
2. `EARSHOT_VOICE`, if it speaks that language;
3. the best installed voice for that language: Premium, then Enhanced, then any;
4. `EARSHOT_VOICE` again, when no voice for the language is installed. The log then says
   `no voice installed for <code>`.

So installing a voice for a language is usually enough; `EARSHOT_VOICES` is only for picking
between several. Permission prompts and questions are read in English with `EARSHOT_VOICE`,
and so is a line read without a summary, when the summary call fails.

The voice set as the macOS system voice is not used. A voice that is not installed falls back to
Samantha, which ships with macOS.

The default, Ava (Premium), is a download: System Settings → Accessibility → Spoken Content →
System Voice → Manage Voices, under English (US). Until it is installed, summaries use the best
English voice you have and prompts use Samantha, which sounds robotic, as the other compact
voices do. Try a voice first with
`say -v "Ava (Premium)" "Review finished"` or `say -v "Zosia (Enhanced)" "Gotowe"`.

### Calls and muting

A call is any time an app records from a microphone: Meet, Zoom, Teams, a Slack huddle, but
also dictation or a voice memo. Before each line, the mic is checked; if it is in use, the line
is shown as a banner and not spoken.

An app that keeps the mic open without being a call, say a wake-word listener or a
push-to-talk tool, can be left out with `EARSHOT_MIC_IGNORE`, a comma-separated list of bundle
IDs or executable names, matched without regard to case:

```json
"EARSHOT_MIC_IGNORE": "com.apple.Siri,corespeechd"
```

Recording by anything on the list is logged as `mic used by com.apple.siri, ignored` and the
line is spoken, unless another app records too. To see what is recording right now, with the
bundle ID and executable name to put on the list, run the check by hand while the mic is in use:

```
/usr/bin/python3 "$(ls -d ~/.claude/plugins/cache/earshot/earshot/*/ | sort -V | tail -1)scripts/mic-in-use.py" --list
```

From a checkout, `python3 scripts/mic-in-use.py --list`. It prints one line per recording
process, e.g. `com.apple.siri, siri`, or nothing when the mic is free.

The banner works for every Claude session at once:

- **Closing it** ends the line being spoken, whether from the banner or from Notification
  Center.
- **Mute 30 min** ends it and keeps everything silent for 30 minutes, counted from the click.
  Lines still appear as banners while muted, with **Unmute** in place of the button; it ends
  the mute early.

To stay silent for good, set `EARSHOT_MUTE` to `1`: every line is then a banner without a
button. `EARSHOT_BANNERS` set to `0` turns the banners off instead, so a muted line or a line
during a call leaves only a log entry.

Banners come from **Earshot**, a helper app inside the plugin (`app/Earshot.app`) that
does nothing but carry the icon; the first banner registers it with macOS. It has its own entry
in System Settings → Notifications, and macOS may ask once whether it may send notifications. A
banner for a line that is not spoken vanishes after a few seconds unless its style is set to
*Alerts* there; its buttons keep working for two minutes. A Focus mode that silences
notifications hides the banners too.

The icon is drawn in `assets/icon.svg`.

### Pausing music

Only an app on the list is paused, and only when it is actually playing. After the line, the app
is resumed only if it is still the current player and still paused, so something you paused or
switched yourself stays as you left it. `EARSHOT_MEDIA` set to `0` turns pausing off.

Video calls are left alone. A call in the browser is a live stream, which the browser does not
offer to the system's play/pause control, so pausing Chrome reaches YouTube and similar players
but not Google Meet. As a second guard, nothing is paused while the now-playing title mentions
Meet, Zoom, Teams, Huddle or Webex.

To pause another app, such as a different browser, set the list in full, e.g. adding Arc:

```json
"EARSHOT_PAUSE_APPS": "com.spotify.client,com.apple.Music,com.apple.podcasts,com.google.Chrome,com.apple.Safari,company.thebrowser.Browser"
```

`media-control get` shows the bundle ID of whatever is playing now. Playback resumes after each
line, so two lines in quick succession pause, resume and pause again.

## Cost and delay

A summary line is heard about 4 seconds after the message appears. Most of that is the summary
call itself, about 3 seconds, and the log records how long each one took (`summary took 3.0s`).
Permission prompts and questions need no call and are read within a second.

Each finished turn makes one Haiku call on your account, a fraction of a cent.

## What was said

Every spoken or skipped line is logged to `~/Library/Logs/earshot.log`
(`~/.local/state/earshot/earshot.log` on Linux), with the time, project, event and voice:

```
2026-10-20 17:02:11 [my-app] Stop: (Ava (Premium)) my-app: Branch reviewed, 31 tests added.
2026-10-20 17:02:11 [my-app] Stop: paused com.spotify.client
2026-10-20 17:05:40 [my-app] Stop: skipped, only waiting on background work
2026-10-20 17:06:02 [my-app] Notification/permission_prompt: (Ava (Premium)) my-app: Claude needs your permission to use Bash
2026-10-20 17:10:15 [my-app] Stop: mic in use, banner only
2026-10-20 17:11:30 [my-app] Stop: mic used by com.apple.siri, ignored
2026-10-20 17:12:40 [my-app] Stop: muted for 30 min
2026-10-20 17:20:03 [my-app] Stop: unmuted
```

If the summary call fails, its error output is logged and the first sentence of the message is
read instead. When no message can be found at all, the line is just *"my-app: done"*. A line
that waits more than two minutes for other sessions to finish speaking is dropped and logged as
such. The log is trimmed to its last 2000 lines when a session starts and it has grown past
4000.

## Known limits

- Call detection needs macOS 14.2 or later; on older systems lines are spoken during calls.
- Sessions speak one at a time. A permission prompt that waited behind another session's line
  is still read out afterwards, even if you have answered it by then.
- If you resume and pause the music yourself while a line is spoken, it is resumed anyway at
  the end, because the player looks exactly as the plugin left it.
- The helper app that carries the banner icon is not code-signed. macOS treats it as any other
  app: it asks once whether it may send notifications, and the entry in System Settings →
  Notifications is where banners can be turned off.
- Permission prompts and questions are always read in English with `EARSHOT_VOICE`; only
  summaries follow the language of the message.
- On Linux, a browser keeps the microphone open while you are muted in a call, so the whole
  call counts as one and nothing is spoken until you leave it.

## Releasing a change

Installed copies run from Claude Code's plugin cache, not from a checkout, and are only replaced
when the version changes. So for every change:

1. Raise `version` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, and
   the two version keys in `app/Earshot.app/Contents/Info.plist`.
2. Run `tests/run.sh`; it also checks that the three versions agree.
3. Commit and push.

The helper app's icon, `AppIcon.icns`, is rendered from `assets/icon.svg`; regenerate it with
`iconutil` from a `.iconset` of PNG exports when the drawing changes.

## Contributing

Issues and pull requests are welcome. The whole plugin is `scripts/earshot.sh`, plain bash
3.2 as shipped with macOS, plus `scripts/mic-in-use.py` for the mic check and
`scripts/session-start.sh` for the log trim and the start-up context. On Linux,
`scripts/linux.sh` replaces the few functions that call macOS tools, and
`scripts/linux-banner.py` stands in for `alerter`. `tests/run.sh` checks the text, voice and
settings helpers without speaking, for both systems. Try a checkout without installing it:
`/plugin marketplace add ~/path/to/earshot`, then `/plugin install earshot@earshot`.

## Uninstall

```
/plugin uninstall earshot@earshot
```
