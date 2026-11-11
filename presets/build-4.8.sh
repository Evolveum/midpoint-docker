#!/usr/bin/env bash
#
# Build midPoint 4.8 with the parameters used for the official images: Java 21, ubuntu, runtime user 'root', in-memory H2 demo repository.
#
# Usage: ./build-4.8.sh [latest|nightly|4.8.Z] [build.sh options]
#   latest   newest 4.8.Z release (default)
#   nightly  newest 4.8 support branch snapshot
#   4.8.Z    a specific release, e.g. 4.8.14
# Further options are passed to build.sh and override the defaults, e.g. --os rockylinux.
set -euo pipefail

SELECTOR="latest"
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    SELECTOR="$1"
    shift
fi

case "${SELECTOR}" in
    latest)  MP_VERSION="4.8-latest" ;;
    nightly) MP_VERSION="4.8-support" ;;
    4.8.*)   MP_VERSION="${SELECTOR}" ;;
    *)       echo "Unknown version '${SELECTOR}' (latest|nightly|4.8.Z)" >&2; exit 1 ;;
esac

exec "$(dirname "$0")/../build.sh" --os ubuntu --java 21 --runtime-user root --h2 "$@" "${MP_VERSION}"
