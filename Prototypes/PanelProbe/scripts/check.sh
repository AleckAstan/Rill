#!/bin/bash
set -euo pipefail
probe_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$probe_root/.build"
xcrun swiftc -swift-version 6 -warnings-as-errors \
  "$probe_root/Sources/PanelGeometry.swift" "$probe_root/Tests/GeometryChecks.swift" \
  -o "$probe_root/.build/geometry-checks"
"$probe_root/.build/geometry-checks"
