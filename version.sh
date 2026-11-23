#!/bin/bash
# Prints version info. Usage: ./version.sh [version|build|tag|full|json]  (default: full)
set -euo pipefail
cd "$(dirname "$0")"

version="$(tr -d '[:space:]' < VERSION)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION: invalid semantic version '$version'" >&2
    exit 1
fi
build="$(git rev-list --count HEAD 2>/dev/null || echo 0)"

case "${1:-full}" in
    version) echo "$version" ;;
    build)   echo "$build" ;;
    tag)     echo "v$version" ;;
    full)    echo "$version+$build" ;;
    json)    printf '{"version":"%s","build":%s,"tag":"v%s"}\n' "$version" "$build" "$version" ;;
    *)       echo "usage: $0 [version|build|tag|full|json]" >&2; exit 2 ;;
esac
