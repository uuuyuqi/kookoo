#!/usr/bin/env bash
# CI-only launch probe. Never runs on a user's Mac; never grants TCC permissions.
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${CI:-}" == true && "${GITHUB_ACTIONS:-}" == true ]]
APP="$(cd "${1:?app bundle required}" && pwd)"
ROOT="$(pwd)"
OUT="$ROOT/dist/engine-gui-evidence"
mkdir -p "$OUT"
WORK=$(mktemp -d "${RUNNER_TEMP:-/tmp}/kookoo-engine-gui.XXXXXX")
PID=''
SAMPLER=''
cleanup() { [[ -z "$SAMPLER" ]] || kill "$SAMPLER" 2>/dev/null || true; [[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT
# Fresh ephemeral runner and isolated app/shell homes. No personal sessions.
export HOME="$WORK/home" CFFIXED_USER_HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
export SHELL=/bin/zsh
cat > "$WORK/render-probe.sh" <<'PROBE'
#!/bin/bash
set -eu
printf '\033[?1049h'
printf 'Alternate screen: 中文 / emoji 🐦 / combining é\n'
sleep 1
printf '\033[?1049l'
for i in $(seq 1 5000); do printf 'scrollback stress %05d 中文\n' "$i"; done
printf '\033[2J\033[H\033[38;2;255;153;51mKOOKOO ENGINE\033[0m\n'
printf '\033[38;2;51;204;221mPinned-source renderer smoke\033[0m\n'
printf 'CJK: 中文输入显示  Emoji: 🐦 🧑‍💻  Combining: é\n'
printf 'ANSI / alternate-screen round-trip / 5000-line scrollback complete\n'
printf '\033]2;KOOKOO_ENGINE_SMOKE_PASS\007'
printf 'PASS\n' > "$1"
sleep 90
PROBE
"$APP/Contents/MacOS/Kookoo" > "$OUT/app.log" 2>&1 & PID=$!
# Observe only this disposable app process's socket metadata, never payloads.
(
  for _ in $(seq 1 60); do
    kill -0 "$PID" 2>/dev/null || exit 0
    date -u '+%FT%TZ'
    /usr/sbin/lsof -nP -a -p "$PID" -i 2>/dev/null || echo 'No IP sockets observed in this sample.'
    sleep 1
  done
) > "$OUT/app-network-samples.txt" & SAMPLER=$!
CLI="$APP/Contents/MacOS/kookoo-cli"
for _ in $(seq 1 40); do
  if "$CLI" status --json > "$OUT/status.json" 2>/dev/null; then break; fi
  kill -0 "$PID"
  sleep 1
done
"$CLI" status --json > "$OUT/status.json"
"$CLI" open --cwd "$WORK" -e "/bin/bash '$WORK/render-probe.sh' '$WORK/terminal-pass'" > "$OUT/open.txt"
for _ in $(seq 1 40); do
  [[ -f "$WORK/terminal-pass" ]] && break
  kill -0 "$PID"
  sleep 1
done
[[ "$(cat "$WORK/terminal-pass")" == PASS ]]
sleep 3
kill -0 "$PID"
"$CLI" list --json > "$OUT/sessions.json"
# OSC-title propagation proves the parser reached the end of the output stream.
grep -q KOOKOO_ENGINE_SMOKE_PASS "$OUT/sessions.json"
if /usr/sbin/screencapture -x "$OUT/screen.png" 2> "$OUT/screenshot-error.txt"; then
  echo 'Screenshot captured; human visual review required.' > "$OUT/screenshot-status.txt"
else
  echo 'Screen capture unavailable on runner. No TCC or security changes attempted.' > "$OUT/screenshot-status.txt"
fi
cat > "$OUT/RESULT.txt" <<RESULT
PASS: app stayed alive; CLI connected; real terminal executed a shell command;
ANSI + alternate-screen output + 5000-line scrollback completed; OSC title
propagated to app session state. This is NOT proof of human IME composition,
keyboard interaction, pane resizing or graphical pixel correctness.
Socket samples are brief process-only observations, not a complete traffic audit.
$(cat "$OUT/screenshot-status.txt")
RESULT
cat "$OUT/RESULT.txt"
