#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
evidence="${1:-$root/phases/04-top-bar/evidence}"
mkdir -p "$evidence"

"$root/scripts/build.sh" > "$evidence/build.log" 2>&1
binary="$root/.build/DerivedData/Build/Products/Debug/Rill.app/Contents/MacOS/Rill"
"$binary" --smoke-report "$evidence/smoke.json" --snapshots "$evidence"
