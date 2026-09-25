#!/bin/bash
set -euo pipefail
probe_root="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$probe_root/PanelProbe.xcodeproj" -scheme PanelProbe \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$probe_root/.build/DerivedData" CODE_SIGN_IDENTITY=- build
