#!/bin/bash
# Runs the test suite. Extra args are passed to `swift test` (e.g. --filter GeometryTests).
set -euo pipefail
cd "$(dirname "$0")"

# SwiftPM intermittently fails to resolve the Swift Testing macro plugin with Command Line Tools only.
TOOLCHAIN_BIN="$(dirname "$(xcrun --find swift)")"
TESTING_PLUGINS="$TOOLCHAIN_BIN/../lib/swift/host/plugins/testing"
if [[ -d "$TESTING_PLUGINS" ]]; then
    swift test -Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS" "$@"
else
    swift test "$@"
fi
