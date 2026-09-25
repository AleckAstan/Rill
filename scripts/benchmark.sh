#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cli="${RILLCTL:-$root/.build/DerivedData/Build/Products/Release/Rill.app/Contents/Resources/bin/rillctl}"
events="${RILL_BENCH_EVENTS:-200}"
if [[ ! -x "$cli" ]]; then
  echo "benchmark: build a Release app first or set RILLCTL to rillctl" >&2
  exit 2
fi
if [[ -z "${RILL_BENCH_SOURCE:-}" ]]; then
  echo "benchmark: set RILL_BENCH_SOURCE to a configured event provider" >&2
  exit 2
fi

start_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
for ((index = 1; index <= events; index++)); do
  "$cli" emit --source "$RILL_BENCH_SOURCE" --name module.update \
    --data "{\"text\":\"bench-$index\",\"value\":$index}" >/dev/null
done
end_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
python3 - "$start_ns" "$end_ns" "$events" <<'PY'
import sys
start, end, events = map(int, sys.argv[1:])
elapsed_ms = (end - start) / 1_000_000
print(f"events={events} elapsed_ms={elapsed_ms:.3f} mean_enqueue_ms={elapsed_ms/events:.3f}")
print("Note: this measures CLI enqueue time, not render latency; pair with Instruments/signposts for p95 event-to-visible timing.")
PY
