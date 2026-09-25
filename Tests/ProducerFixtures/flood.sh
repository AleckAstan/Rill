#!/bin/sh
set -eu
index=0
while [ "$index" -lt 1000 ]; do
  /usr/bin/printf '{"version":1,"type":"module.update","data":{"text":"%s"}}\n' "$index"
  index=$((index + 1))
done
