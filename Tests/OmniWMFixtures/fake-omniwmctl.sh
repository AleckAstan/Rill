#!/bin/sh
set -eu

if [ -n "${OMNIWM_QUERY_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$OMNIWM_QUERY_LOG"
fi

case "${1:-} ${2:-}" in
  "query workspaces")
    printf '%s\n' '{"version":16,"id":"fixture","kind":"query","ok":true,"status":"success","result":{"kind":"workspaces","payload":{"workspaces":[{"id":"workspace:1","rawName":"1","displayName":"Code","number":1,"display":{"id":"display:main","name":"Studio Display","isMain":true},"isFocused":true,"isVisible":true,"isCurrent":true,"counts":{"total":2,"tiled":2,"floating":0,"scratchpad":0},"focusedWindowId":"window:1"},{"id":"workspace:2","rawName":"Media & TV","displayName":"Media & TV","number":2,"display":{"id":"display:main","name":"Studio Display","isMain":true},"isFocused":false,"isVisible":false,"isCurrent":false,"counts":{"total":0,"tiled":0,"floating":0,"scratchpad":0}}]}}}'
    ;;
  "query workspace-bar")
    printf '%s\n' '{"version":16,"id":"fixture","kind":"query","ok":true,"status":"success","result":{"kind":"workspace-bar","payload":{"interactionMonitorId":"display:main","monitors":[{"id":"display:main","name":"Studio Display","enabled":true,"isVisible":true,"showLabels":true,"backgroundOpacity":0.8,"barHeight":28,"scratchpads":[],"workspaces":[{"id":"workspace:1","rawName":"1","displayName":"Code","number":1,"isFocused":true,"windows":[{"id":"app:finder","appName":"Finder","bundleId":"com.apple.finder","isFocused":true,"windowCount":2,"allWindows":[]}]},{"id":"workspace:2","rawName":"Media & TV","displayName":"Media & TV","number":2,"isFocused":false,"windows":[]}] }]}}}'
    ;;
  "query focused-window")
    printf '%s\n' '{"version":16,"id":"fixture","kind":"query","ok":true,"status":"success","result":{"kind":"focused-window","payload":{"window":{"id":"window:1","pid":42,"workspace":{"id":"workspace:1","rawName":"1","displayName":"Code","number":1},"display":{"id":"display:main","name":"Studio Display","isMain":true},"app":{"name":"Fixture App","bundleId":"dev.rill.fixture"},"title":"Fixture title"}}}}'
    ;;
  "workspace focus-name")
    [ "$#" -eq 3 ] || { printf '%s\n' "workspace name was split" >&2; exit 7; }
    [ "${3:-}" = "Media & TV" ] || { printf '%s\n' "unexpected workspace" >&2; exit 8; }
    printf '%s\n' "$3" > "${OMNIWM_TEST_LOG:?}"
    printf '%s\n' '{"version":16,"id":"fixture","kind":"workspace","ok":true,"status":"executed"}'
    ;;
  "subscribe workspace-bar,focus")
    printf '%s\n' '{"version":16,"id":"fixture","kind":"subscribe","ok":true,"status":"subscribed","result":{"kind":"subscribed","payload":{"channels":["workspace-bar","focus"]}}}'
    printf '%s\n' '{"version":16,"id":"fixture","kind":"event","channel":"workspace-bar","ok":true,"status":"success","result":{"kind":"workspace-bar","payload":{"interactionMonitorId":"display:main","monitors":[]}}}'
    ;;
  *)
    printf '%s\n' "unsupported fake command: $*" >&2
    exit 9
    ;;
esac
