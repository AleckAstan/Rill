#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  /usr/bin/printf 'usage: %s /absolute/path/to/yabai [provider-id]\n' "$0" >&2
  exit 2
fi

yabai=$1
source_id=${2:-yabai}
events="space_changed space_created space_destroyed display_added display_removed display_moved display_changed window_created window_destroyed window_focused window_moved"

for event in $events; do
  "$yabai" -m signal --remove "rill-$source_id-$event" >/dev/null 2>&1 || true
done

/usr/bin/printf 'Removed labeled Rill hooks for provider %s.\n' "$source_id"
