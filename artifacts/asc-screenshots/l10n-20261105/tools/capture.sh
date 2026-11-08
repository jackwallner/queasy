#!/bin/sh
# Capture every scene in scenes.json for en-US plus the target locales in one
# gh-sim launch job (iPhone 17 Pro Max), then sort shots into raw/<locale>/phone/.
# Usage: capture.sh [store_locale ...]   (no args: all targets in app.json)
set -eu
cd "$(dirname "$0")/.."
REPO=$(cd ../../.. && pwd)
exec "$(dirname "$0")/../.venv/bin/python" tools/capture.py "$REPO" "$@"
