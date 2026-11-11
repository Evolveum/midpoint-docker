#!/usr/bin/env bash
#
# Build midPoint 4.11 with the parameters used for the official images: Java 25, alpine, runtime user 'midpoint'.
#
# Usage: ./build-4.11.sh [latest|nightly|4.11.Z] [build.sh options]
#   latest   newest 4.11.Z release (default)
#   nightly  newest 4.11 support branch snapshot
#   4.11.Z   a specific release, e.g. 4.11.0
# Further options are passed to build.sh and override the defaults, e.g. --os rockylinux.
set -euo pipefail

SELECTOR="latest"
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    SELECTOR="$1"
    shift
fi

case "${SELECTOR}" in
    latest)  MP_VERSION="4.11-latest" ;;
    nightly) MP_VERSION="4.11-support" ;;
    4.11.*)  MP_VERSION="${SELECTOR}" ;;
    *)       echo "Unknown version '${SELECTOR}' (latest|nightly|4.11.Z)" >&2; exit 1 ;;
esac

exec "$(dirname "$0")/../build.sh" --os alpine --java 25 --runtime-user midpoint "$@" "${MP_VERSION}"
