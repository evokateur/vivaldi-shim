#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM="$ROOT/build/Vivaldi Shim.app"
RUN_ID="$(uuidgen)"
MISSING=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

is_running() { pgrep -x Vivaldi >/dev/null; }

window_count() {
  osascript -e 'tell application "Vivaldi" to return (count of windows)'
}

tab_list() {
  osascript <<'APPLESCRIPT'
tell application "Vivaldi"
  set report to ""
  repeat with theWindow in windows
    set report to report & "Window " & (id of theWindow) & ": " & (count of tabs of theWindow) & " tab(s)" & linefeed
    repeat with theTab in tabs of theWindow
      set report to report & (URL of theTab) & linefeed
    end repeat
  end repeat
  return report
end tell
APPLESCRIPT
}

wait_for() {
  local attempt
  for attempt in {1..10}; do
    "$@" && return 0
    sleep 1
  done
  return 1
}

assert_state() {
  case "$1" in
    cold) ! is_running ;;
    nowin) is_running && [ "$(window_count)" = 0 ] ;;
    win) is_running && [ "$(window_count)" -ge 1 ] ;;
  esac
}

normalize() {
  case "$1" in
    cold)
      if is_running; then
        osascript -e 'tell application "Vivaldi" to quit' >/dev/null || return 1
      fi
      wait_for assert_state cold
      ;;
    nowin)
      if ! is_running; then
        normalize win || return 1
      fi
      osascript -e 'tell application "Vivaldi" to close every window' >/dev/null || return 1
      sleep 3
      assert_state nowin
      ;;
    win)
      assert_state win && return 0
      open -a Vivaldi || return 1
      wait_for assert_state win || return 1
      sleep 2
      ;;
  esac
}

has_urls() {
  is_running || return 1
  local tabs url
  tabs="$(tab_list)" || return 1
  for url in "$@"; do
    printf '%s\n' "$tabs" | grep -Fx -- "$url" >/dev/null || return 1
  done
}

shim_exited() { ! pgrep -x 'Vivaldi Shim' >/dev/null; }

test_url() {
  local browser="$1" state="$2" url="$3"
  printf '\nTesting %s: %s\n' "$browser" "$state"
  normalize "$state" || fail "could not prepare $state"
  assert_state "$state" || fail "state changed before dispatch: $state"
  open -a "$browser" "$url" || fail 'URL dispatch failed'
  if wait_for has_urls "$url"; then
    printf 'PASS: URL opened\n'
  else
    printf 'MISSING: %s\n' "$url"
    MISSING=$((MISSING + 1))
  fi
  if [ "$browser" = "$SHIM" ]; then
    wait_for shim_exited || fail 'shim stayed running'
  fi
  sleep 2
  if is_running; then
    tab_list || fail 'could not read Vivaldi tabs'
  else
    printf 'Vivaldi is not running.\n'
  fi
}

main() {
  "$ROOT/scripts/build-shim.sh" --build-only
  printf 'Quitting Vivaldi after closing all its windows..\n'
  printf 'Do not touch Vivaldi during the run.\n'
  local browser state trial=0
  for browser in Vivaldi "$SHIM"; do
    for state in cold nowin win; do
      trial=$((trial + 1))
      test_url "$browser" "$state" "https://example.com/?probe=$RUN_ID-$trial"
    done
  done
  printf '\nFinished: %s missing URL(s). Compare the window/tab lists above.\n' "$MISSING"
  [ "$MISSING" -eq 0 ]
}

main
