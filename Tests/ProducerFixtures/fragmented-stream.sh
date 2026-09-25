#!/bin/sh
set -eu
/usr/bin/printf '{"version":1,"type":"module.'
/bin/sleep 0.05
/usr/bin/printf 'update","data":{"text":"stream first"}}\n{"version":1,"type":"module.update","data":{"text":"stream visible","state":"warning"}}\n'
