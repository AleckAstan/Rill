#!/bin/sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  /usr/bin/printf 'usage: %s /absolute/path/to/yabai /absolute/path/to/rillctl [provider-id]\n' "$0" >&2
  exit 2
fi

yabai=$1
rillctl=$2
source_id=${3:-yabai}

case "$yabai:$rillctl" in
  /*:/*) ;;
  *) /usr/bin/printf 'yabai and rillctl paths must be absolute\n' >&2; exit 2 ;;
esac

action="\"$rillctl\" emit --source \"$source_id\" --name refresh --data '{}'"
events="space_changed space_created space_destroyed display_added display_removed display_moved display_changed window_created window_destroyed window_focused window_moved"

for event in $events; do
  label="rill-$source_id-$event"
  "$yabai" -m signal --remove "$label" >/dev/null 2>&1 || true
  "$yabai" -m signal --add label="$label" event="$event" action="$action"
done

/usr/bin/printf 'Installed 11 labeled Rill hooks for provider %s.\n' "$source_id"
