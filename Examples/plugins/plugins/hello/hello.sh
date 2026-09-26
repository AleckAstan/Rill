#!/bin/sh
# A plugin is an NDJSON stream. Rill supervises this process and restarts it
# with bounded backoff if it exits. The environment also contains
# RILL_PLUGIN_ID, RILL_PLUGIN_DIRECTORY and RILL_PLUGIN_API_VERSION.
sleep 1
while :; do
  printf '%s\n' '{"version":1,"type":"module.update","data":{"text":"Hello Rill","tooltip":"Click for details","state":"success","popover":"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."}}'
  sleep 30
done
