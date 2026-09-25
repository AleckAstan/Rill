#!/bin/sh
set -eu
: "${YABAI_SIGNAL_REGISTRY:?set YABAI_SIGNAL_REGISTRY}"
/usr/bin/touch "$YABAI_SIGNAL_REGISTRY"

if [ "${1:-}" != "-m" ] || [ "${2:-}" != "signal" ]; then exit 2; fi

case "${3:-}" in
  --remove)
    label=${4:-}
    /usr/bin/awk -F '|' -v wanted="$label" '$1 != wanted' "$YABAI_SIGNAL_REGISTRY" > "$YABAI_SIGNAL_REGISTRY.next"
    /bin/mv "$YABAI_SIGNAL_REGISTRY.next" "$YABAI_SIGNAL_REGISTRY"
    ;;
  --add)
    shift 3
    label=""; event=""; action=""
    for argument in "$@"; do
      case "$argument" in
        label=*) label=${argument#label=} ;;
        event=*) event=${argument#event=} ;;
        action=*) action=${argument#action=} ;;
      esac
    done
    [ -n "$label" ] && [ -n "$event" ] && [ -n "$action" ]
    /usr/bin/printf '%s|%s|%s\n' "$label" "$event" "$action" >> "$YABAI_SIGNAL_REGISTRY"
    ;;
  --list) /bin/cat "$YABAI_SIGNAL_REGISTRY" ;;
  *) exit 2 ;;
esac
