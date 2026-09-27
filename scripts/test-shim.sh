#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM="$ROOT/build/Vivaldi Shim.app"
RUN_ID="$(uuidgen)"

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
      normalize win || return 1
      osascript -e 'tell application "Vivaldi" to close every window' >/dev/null || return 1
      sleep 3
      assert_state nowin
      ;;
    win)
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

check_exit() {
  wait_for shim_exited || fail 'shim stayed running'
}

test_urls() {
  local state="$1"
  shift
  printf 'Testing URL delivery: %s (%s URLs)\n' "$state" "$#"
  normalize "$state" || fail "could not prepare $state"
  assert_state "$state" || fail "state changed before dispatch: $state"
  open -n -a "$SHIM" "$@" || fail 'URL dispatch failed'
  if ! wait_for has_urls "$@"; then
    printf 'Expected URLs:\n%s\n' "$*" >&2
    tab_list >&2
    fail "missing URL in $state"
  fi
  check_exit
  printf 'PASS\n'
}

test_plain_launch() {
  printf 'Testing launch without a URL\n'
  normalize cold || fail 'could not quit Vivaldi'
  assert_state cold || fail 'state changed before plain launch'
  open -n -a "$SHIM" || fail 'plain launch failed'
  wait_for assert_state win || fail 'plain launch did not open Vivaldi'
  check_exit
  printf 'PASS\n'
}

main() {
  "$ROOT/scripts/build-shim.sh" --build-only
  printf 'This test quits Vivaldi and closes all its windows. Save work first.\n'
  printf 'Do not touch Vivaldi during the run.\n'
  local state
  for state in cold nowin win; do
    test_urls "$state" "https://example.com/?probe=$RUN_ID-$state"
  done
  test_urls win "https://example.com/?probe=$RUN_ID-multi-1" \
    "https://example.com/?probe=$RUN_ID-multi-2"
  test_plain_launch
  printf 'All 5 checks passed.\n'
}

main
