#!/usr/bin/env bash
#
# Build the newest development snapshot (master) with the parameters used for the official nightly
# images: Java 25, alpine, runtime user 'midpoint'.
#
# Usage: ./build-nightly.sh [build.sh options]
set -euo pipefail

exec "$(dirname "$0")/../build.sh" --os alpine --java 25 --runtime-user midpoint "$@" devel
