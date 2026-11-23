#!/bin/bash
# Runs the test suite. Extra args are passed to `swift test` (e.g. --filter GeometryTests).
set -euo pipefail
cd "$(dirname "$0")"
swift test "$@"
