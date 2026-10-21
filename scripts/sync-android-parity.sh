#!/bin/bash
# Compiles the iOS model and engine sources with a small exporter and writes
# the parity fixture the Android JVM tests read (PortParityTest).
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo/android/app/src/test/resources/queasy-parity.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$(dirname "$out")"
swiftc -O -o "$tmp/export" \
  "$repo/Shared/Models/ReliefMode.swift" \
  "$repo/Shared/Models/ReliefPlan.swift" \
  "$repo/Shared/Services/PatternEngine.swift" \
  "$repo/Shared/Services/FreeTier.swift" \
  "$repo/scripts/android-export/main.swift"
"$tmp/export" "$out"
