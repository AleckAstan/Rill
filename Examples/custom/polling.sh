#!/bin/sh
set -eu
timestamp=$(/bin/date '+%H:%M:%S')
/usr/bin/printf '{"version":1,"type":"module.update","data":{"text":"polled %s","tooltip":"Command provider example","state":"success"}}\n' "$timestamp"
