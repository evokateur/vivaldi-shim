#!/usr/bin/env bash
#
# matrix-test.sh - Determine exactly when Vivaldi loads a URL handed to it on macOS.
#
# Tests four dispatch paths against three Vivaldi states. Each trial normalizes
# Vivaldi into the intended state, ASSERTS that state immediately before handing
# over the URL, and aborts the trial if the assertion fails - so a browser touched
# mid-run produces a SKIP, never a bogus PASS.
#
# Two paths address Vivaldi directly and serve as controls: 'open -a' reproduces
# the bug when Vivaldi is running with no windows, 'exec' does not. The other two
# go through the shim - 'shim' targets it explicitly, 'bare' reaches it as the
# system default handler, and both are expected to load in every state.
#
# Full before/after tab lists go to the log file for auditing.
#
# Usage:
#   ./matrix-test.sh              # 2 trials per combination
#   ./matrix-test.sh 3            # 3 trials per combination
#
# Do not touch Vivaldi while this runs.

set -uo pipefail

VIVALDI_BIN="/Applications/Vivaldi.app/Contents/MacOS/Vivaldi"
SHIM_NAME="VivaldiShim"
PATHS="bare open-a exec shim"
TRIALS="${1:-2}"
LOG="$(dirname "$0")/matrix-test.log"
RESULTS="$(mktemp)"

: >"$LOG"

log() { printf '%s\n' "$*" >>"$LOG"; }

is_running() { pgrep -x Vivaldi >/dev/null 2>&1; }

window_count() {
  is_running || { echo 0; return; }
  osascript -e 'tell application "Vivaldi" to return (count of windows)' 2>/dev/null || echo "?"
}

tab_list() {
  is_running || return 0
  osascript <<'APPLESCRIPT' 2>/dev/null
tell application "Vivaldi"
  set report to ""
  set windowIndex to 0
  repeat with theWindow in windows
    set windowIndex to windowIndex + 1
    repeat with theTab in tabs of theWindow
      set report to report & "w" & windowIndex & " " & (URL of theTab) & linefeed
    end repeat
  end repeat
  return report
end tell
APPLESCRIPT
}

quit_vivaldi() {
  is_running || return 0
  osascript -e 'tell application "Vivaldi" to quit' >/dev/null 2>&1
  for _ in 1 2 3 4 5 6 7 8; do
    is_running || return 0
    sleep 1
  done
  return 1
}

launch_bare() {
  open -a Vivaldi
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(window_count)" -ge 1 ] 2>/dev/null && { sleep 2; return 0; }
    sleep 1
  done
  return 1
}

# Put Vivaldi into the requested state. Returns non-zero if it cannot be reached.
normalize() {
  case "$1" in
    cold)
      quit_vivaldi
      ;;
    nowin)
      is_running || launch_bare || return 1
      osascript -e 'tell application "Vivaldi" to close every window' >/dev/null 2>&1
      sleep 3
      [ "$(window_count)" = "0" ]
      ;;
    win)
      quit_vivaldi || return 1
      launch_bare || return 1
      [ "$(window_count)" -ge 1 ] 2>/dev/null
      ;;
  esac
}

# Confirm Vivaldi really is in the requested state right now.
assert_state() {
  case "$1" in
    cold)  ! is_running ;;
    nowin) is_running && [ "$(window_count)" = "0" ] ;;
    win)   is_running && [ "$(window_count)" -ge 1 ] 2>/dev/null ;;
  esac
}

dispatch() {
  case "$1" in
    bare)   open "$2" ;;
    open-a) open -a Vivaldi "$2" ;;
    exec)   "$VIVALDI_BIN" "$2" >/dev/null 2>&1 & ;;
    shim)   open -a "$SHIM_NAME" "$2" ;;
  esac
}

run_trial() {
  local state="$1" path="$2" trial="$3"
  local url="https://example.com/?probe=${state}-${path}-${trial}-$(date +%s)"

  log "=============================================================="
  log "state=$state path=$path trial=$trial"

  if ! normalize "$state"; then
    log "  NORMALIZE FAILED"
    echo "$state|$path|SKIP(normalize)" >>"$RESULTS"
    return
  fi

  log "  tabs at dispatch (windows=$(window_count)):"
  log "$(tab_list | sed 's/^/    /')"

  if ! assert_state "$state"; then
    log "  ASSERT FAILED - state drifted, skipping"
    echo "$state|$path|SKIP(assert)" >>"$RESULTS"
    return
  fi

  log "  dispatching: $url"
  dispatch "$path" "$url"
  sleep 6

  local after
  after="$(tab_list)"
  log "  tabs after (windows=$(window_count)):"
  log "$(printf '%s' "$after" | sed 's/^/    /')"

  if printf '%s' "$after" | grep -qF "$url"; then
    log "  => LOADED"
    echo "$state|$path|LOADED" >>"$RESULTS"
  else
    log "  => DROPPED"
    echo "$state|$path|DROPPED" >>"$RESULTS"
  fi
}

summarize() {
  echo
  echo "RESULTS ($TRIALS trials per combination)"
  echo
  printf '%-22s %-10s %-10s %-10s %s\n' "STATE" "bare" "open -a" "exec" "shim"
  for state in cold nowin win; do
    local row=""
    for path in $PATHS; do
      local outcomes
      outcomes="$(grep "^$state|$path|" "$RESULTS" | cut -d'|' -f3 | sort -u | paste -sd, -)"
      [ -z "$outcomes" ] && outcomes="-"
      row="$row$(printf '%-10s ' "$outcomes")"
    done
    printf '%-22s %s\n' "$(state_label "$state")" "$row"
  done
  echo
  echo "Full tab-level detail: $LOG"
}

state_label() {
  case "$1" in
    cold)  echo "not running" ;;
    nowin) echo "running, 0 windows" ;;
    win)   echo "running, >=1 window" ;;
  esac
}

main() {
  echo "Testing Vivaldi URL dispatch. Do not touch the browser while this runs."
  echo "Trials per combination: $TRIALS"
  echo "The 'bare' path follows the system default handler, so it only exercises"
  echo "the shim while the default chain points at it."
  echo

  for state in cold nowin win; do
    for path in $PATHS; do
      for trial in $(seq 1 "$TRIALS"); do
        printf '  %-20s %-8s trial %s ... ' "$(state_label "$state")" "$path" "$trial"
        run_trial "$state" "$path" "$trial"
        tail -1 "$RESULTS" | cut -d'|' -f3
      done
    done
  done

  summarize

  local stray
  stray="$(pgrep -x "$SHIM_NAME")"
  [ -n "$stray" ] && echo "WARNING: $SHIM_NAME still resident (pid $stray)"

  rm -f "$RESULTS"
}

main
