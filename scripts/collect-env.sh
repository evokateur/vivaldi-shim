#!/usr/bin/env bash
#
# collect-env.sh - Dump the environment and Vivaldi configuration facts needed
# for the URL-dispatch bug report.
#
# Writes <hostname>-env.txt next to this script. Run it on each machine under
# test and collect the files; the output is plain "key = value" lines so two
# machines can be compared with diff.
#
# Usage: ./collect-env.sh

set -uo pipefail

VIVALDI_APP="/Applications/Vivaldi.app"
PREFS="$HOME/Library/Application Support/Vivaldi/Default/Preferences"
LAUNCH_SERVICES="$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"

HOST="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
HOST="$(printf '%s' "$HOST" | tr ' /' '--')"
OUT="$(dirname "$0")/${HOST}-env.txt"

emit() { printf '%-28s = %s\n' "$1" "$2" >>"$OUT"; }

section() { printf '\n[%s]\n' "$1" >>"$OUT"; }

# Value of a jq path in the Vivaldi preferences, or "unset" when absent.
# Distinguishes a genuine false/0 from a missing key.
pref() {
  [ -f "$PREFS" ] || { echo "PREFS NOT FOUND"; return; }
  jq -r "$1 | if . == null then \"unset\" else tostring end" "$PREFS" 2>/dev/null \
    || echo "READ ERROR"
}

# Bundle id registered to handle a URL scheme, or "none registered".
handler_for() {
  local scheme="$1" result
  result="$(plutil -convert json -o - "$LAUNCH_SERVICES" 2>/dev/null \
    | jq -r --arg s "$scheme" \
        '.LSHandlers[]? | select(.LSHandlerURLScheme == $s) | .LSHandlerRoleAll' 2>/dev/null \
    | head -1)"
  echo "${result:-none registered (system default)}"
}

collect_host() {
  section "host"
  emit "hostname" "$HOST"
  emit "collected" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
}

collect_system() {
  section "system"
  emit "macos_version" "$(sw_vers -productVersion)"
  emit "macos_build" "$(sw_vers -buildVersion)"
  emit "arch" "$(uname -m)"
  emit "cpu" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
}

collect_vivaldi() {
  section "vivaldi"
  if [ -d "$VIVALDI_APP" ]; then
    emit "version" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
      "$VIVALDI_APP/Contents/Info.plist" 2>/dev/null)"
    emit "bundle_version" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
      "$VIVALDI_APP/Contents/Info.plist" 2>/dev/null)"
    emit "bundle_id" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
      "$VIVALDI_APP/Contents/Info.plist" 2>/dev/null)"
  else
    emit "version" "NOT INSTALLED at $VIVALDI_APP"
  fi
  emit "running" "$(pgrep -x Vivaldi >/dev/null && echo yes || echo no)"
}

collect_handlers() {
  section "url handlers"
  emit "https_handler" "$(handler_for https)"
  emit "http_handler" "$(handler_for http)"
}

collect_prefs() {
  section "vivaldi startup configuration"
  if [ ! -f "$PREFS" ]; then
    emit "profile" "NOT FOUND at $PREFS"
    return
  fi
  emit "profile" "Default"
  emit "session.restore_on_startup" "$(pref '.session.restore_on_startup')"
  emit "session.startup_urls" "$(pref '.session.startup_urls')"
  emit "vivaldi.homepage" "$(pref '.vivaldi.homepage')"
  emit "vivaldi.startpage.navigation" "$(pref '.vivaldi.startpage.navigation')"
  emit "profile.exited_cleanly" "$(pref '.profile.exited_cleanly')"
}

main() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ABORT: jq is required but not installed." >&2
    exit 1
  fi

  : >"$OUT"
  collect_host
  collect_system
  collect_vivaldi
  collect_handlers
  collect_prefs

  cat "$OUT"
  echo
  echo "written to: $OUT"
}

main
