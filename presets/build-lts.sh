#!/usr/bin/env bash
#
# Build the current LTS line (midPoint 4.8). Same arguments as build-4.8.sh:
#   ./build-lts.sh            newest 4.8.Z release
#   ./build-lts.sh nightly    newest 4.8 support branch snapshot
#   ./build-lts.sh 4.8.14     a specific release
set -euo pipefail

exec "$(dirname "$0")/build-4.8.sh" "$@"
