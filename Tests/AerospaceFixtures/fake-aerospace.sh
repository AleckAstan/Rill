#!/bin/sh
set -eu
case "${1:-}" in
  list-workspaces)
    printf '%s\n' '[{"workspace":"1","monitor-id":1,"workspace-is-focused":true,"workspace-is-visible":true},{"workspace":"Media & TV","monitor-id":1,"workspace-is-focused":false,"workspace-is-visible":false},{"workspace":"équipe","monitor-id":2,"workspace-is-focused":false,"workspace-is-visible":false},{"workspace":"","monitor-id":2,"workspace-is-focused":false,"workspace-is-visible":false}]'
    ;;
  list-windows)
    if [ "${2:-}" = "--focused" ]; then
      printf '%s\n' '[{"app-name":"Fixture App","window-id":42,"window-title":"Fixture title"}]'
    elif [ "${2:-}" = "--all" ]; then
      printf '%s\n' '[{"window-id":42,"workspace":"1","app-name":"Fixture App","app-bundle-id":"dev.rill.fixture"},{"window-id":43,"workspace":"1","app-name":"Fixture App","app-bundle-id":"dev.rill.fixture"},{"window-id":44,"workspace":"équipe","app-name":"Finder","app-bundle-id":"com.apple.finder"}]'
    else
      printf '%s\n' 'unsupported list-windows arguments' >&2
      exit 8
    fi
    ;;
  workspace)
    [ "${2:-}" = 'Media & TV' ] || { printf '%s\n' 'unexpected workspace argument' >&2; exit 7; }
    ;;
  *) printf '%s\n' 'unsupported fake command' >&2; exit 9;;
esac
