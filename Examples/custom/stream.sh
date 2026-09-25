#!/bin/sh
set -eu
counter=1
while :; do
  /usr/bin/printf '{"version":1,"type":"module.update","data":{"text":"stream %s","tooltip":"NDJSON stream example","value":%s}}\n' "$counter" "$counter"
  counter=$((counter + 1))
  /bin/sleep 2
done
