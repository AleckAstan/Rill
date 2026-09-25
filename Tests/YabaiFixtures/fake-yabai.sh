#!/bin/sh
set -eu

if [ -n "${YABAI_TEST_LOG:-}" ]; then
  /usr/bin/printf '%s\n' "$*" >> "$YABAI_TEST_LOG"
fi

if [ "${YABAI_FAIL_QUERY:-0}" = "1" ] && [ "${2:-}" = "query" ]; then
  /usr/bin/printf 'accessibility permission denied\n' >&2
  exit 7
fi

if [ "${2:-}" = "query" ]; then
  case "${3:-}" in
    --displays) /bin/cat "$YABAI_FIXTURES/displays-multi.json" ;;
    --spaces) /bin/cat "$YABAI_FIXTURES/spaces-multi.json" ;;
    --windows) /bin/cat "$YABAI_FIXTURES/window-focused.json" ;;
    *) exit 2 ;;
  esac
  exit 0
fi

if [ "${2:-}" = "space" ] && [ "${3:-}" = "--focus" ]; then
  if [ "${YABAI_DENY_FOCUS:-0}" = "1" ]; then
    /usr/bin/printf 'cannot focus space: scripting addition unavailable\n' >&2
    exit 3
  fi
  exit 0
fi

exit 2
