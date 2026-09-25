#!/bin/bash
set -euo pipefail
probe_root="$(cd "$(dirname "$0")/.." && pwd)"
evidence_dir="$probe_root/../../phases/01-platform-feasibility/evidence"
mkdir -p "$evidence_dir"
"$probe_root/.build/DerivedData/Build/Products/Debug/PanelProbe.app/Contents/MacOS/PanelProbe" \
  --smoke-test --report "$evidence_dir/smoke.json" --snapshots "$evidence_dir"
