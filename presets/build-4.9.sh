#!/usr/bin/env bash
#
# Build midPoint 4.9 with the parameters used for the official images: Java 21, ubuntu, runtime user 'root'.
#
# Usage: ./build-4.9.sh [latest|nightly|4.9.Z] [build.sh options]
#   latest   newest 4.9.Z release (default)
#   nightly  newest 4.9 support branch snapshot
#   4.9.Z    a specific release, e.g. 4.9.9
# Further options are passed to build.sh and override the defaults, e.g. --os rockylinux.
set -euo pipefail

SELECTOR="latest"
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    SELECTOR="$1"
    shift
fi

case "${SELECTOR}" in
    latest)  MP_VERSION="4.9-latest" ;;
    nightly) MP_VERSION="4.9-support" ;;
    4.9.*)   MP_VERSION="${SELECTOR}" ;;
    *)       echo "Unknown version '${SELECTOR}' (latest|nightly|4.9.Z)" >&2; exit 1 ;;
esac

exec "$(dirname "$0")/../build.sh" --os ubuntu --java 21 --runtime-user root "$@" "${MP_VERSION}"
