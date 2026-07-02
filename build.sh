#!/usr/bin/env bash
#
# Build a midPoint container image from the Dockerfiles in dockerfiles/.
#
# The image is assembled in three stages, all built locally by this script:
#   1. base  - OS + JDK           (dockerfiles/Dockerfile-base)
#   2. dist  - midPoint payload   (dockerfiles/Dockerfile-dist, FROM scratch + the Nexus dist tarball)
#   3. final - runnable image     (dockerfiles/Dockerfile, FROM base + COPY --from dist)
#
# The dist tarball is fetched from the public Nexus by ./download-midpoint (no credentials needed).
# By default all three stages are built locally; pass --base-image / --dist-image to reuse a prebuilt
# stage from a registry and skip building it.
#
# Usage:
#   ./build.sh [options] [MP_VERSION]
#
#   MP_VERSION            midPoint version to build (default: latest). Accepts a release (e.g. 4.9.1),
#                         'latest' (newest release), 'devel' (newest snapshot), or 'X.Y-support'.
#
# Options:
#   --os FAMILY          Base OS family: alpine | ubuntu | rockylinux   (default: alpine)
#   --os-tag TAG         Base OS image tag                              (default per family)
#   --java VERSION       JDK version                                    (default: 21)
#   --runtime-user USER  root | midpoint   (midPoint 4.11+ runs as the non-root midpoint user; default: midpoint)
#   --h2                 Enable the in-memory H2 demo repository defaults (default: off)
#   --base-image REF     Use this prebuilt base image (skip building base), e.g. registry.evolveum.com/public/midpoint-base:21-alpine
#   --dist-image REF     Use this prebuilt dist image (skip download + building dist)
#   --image NAME         Final image name                              (default: midpoint)
#   --tag TAG            Final image tag                               (default: <MP_VERSION>-<os>)
#   -h, --help           Show this help.
#
# Examples:
#   ./build.sh                              # latest release, alpine, non-root
#   ./build.sh --os ubuntu 4.9.1            # a specific release on ubuntu
#   ./build.sh --base-image registry.evolveum.com/public/midpoint-base:21-alpine devel
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CTX="${DIR}/dockerfiles"

# Defaults.
MP_VERSION="latest"
OS_FAMILY="alpine"
OS_TAG=""
JAVA_VERSION="21"
RUNTIME_USER="midpoint"
H2_DEFAULTS="false"
BASE_IMAGE=""
DIST_IMAGE=""
IMAGE_NAME="midpoint"
IMAGE_TAG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --os)           OS_FAMILY="$2"; shift 2 ;;
        --os-tag)       OS_TAG="$2"; shift 2 ;;
        --java)         JAVA_VERSION="$2"; shift 2 ;;
        --runtime-user) RUNTIME_USER="$2"; shift 2 ;;
        --h2)           H2_DEFAULTS="true"; shift ;;
        --base-image)   BASE_IMAGE="$2"; shift 2 ;;
        --dist-image)   DIST_IMAGE="$2"; shift 2 ;;
        --image)        IMAGE_NAME="$2"; shift 2 ;;
        --tag)          IMAGE_TAG="$2"; shift 2 ;;
        -h|--help)      sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'; exit 0 ;;
        -*)             echo "Unknown option: $1" >&2; exit 1 ;;
        *)              MP_VERSION="$1"; shift ;;
    esac
done

# Default base OS tag per family (state-of-the-art rolling defaults).
if [ -z "${OS_TAG}" ]; then
    case "${OS_FAMILY}" in
        alpine)     OS_TAG="3.24" ;;
        ubuntu)     OS_TAG="24.04" ;;
        rockylinux) OS_TAG="10" ;;
        *)          echo "Unsupported --os '${OS_FAMILY}' (alpine|ubuntu|rockylinux)" >&2; exit 1 ;;
    esac
fi

[ -z "${IMAGE_TAG}" ] && IMAGE_TAG="${MP_VERSION}-${OS_FAMILY}"

# Local stage tags (used when we build a stage ourselves).
BASE_REF="${BASE_IMAGE:-midpoint-base:local-${OS_FAMILY}}"
DIST_REF="${DIST_IMAGE:-midpoint-dist:local}"
FINAL_REF="${IMAGE_NAME}:${IMAGE_TAG}"
DIST_FILE="midpoint-dist.tar.gz"   # relative to the build context (dockerfiles/)

split_name() { printf '%s' "${1%:*}"; }
split_tag()  { printf '%s' "${1##*:}"; }

echo "==> midPoint ${MP_VERSION} | os=${OS_FAMILY}:${OS_TAG} | java=${JAVA_VERSION} | user=${RUNTIME_USER} | h2=${H2_DEFAULTS}"
echo "    base=${BASE_REF}${BASE_IMAGE:+ (prebuilt)}  dist=${DIST_REF}${DIST_IMAGE:+ (prebuilt)}  final=${FINAL_REF}"

# 1. base
if [ -z "${BASE_IMAGE}" ]; then
    echo "==> [1/3] building base image ${BASE_REF}"
    docker build -f "${CTX}/Dockerfile-base" -t "${BASE_REF}" \
        --build-arg base_image="${OS_FAMILY}" \
        --build-arg base_image_tag="${OS_TAG}" \
        --build-arg base_os_family="${OS_FAMILY}" \
        --build-arg JAVA_VERSION="${JAVA_VERSION}" \
        "${CTX}"
else
    echo "==> [1/3] using prebuilt base ${BASE_REF}"
fi

# 2. dist (download tarball + build the scratch payload image)
if [ -z "${DIST_IMAGE}" ]; then
    echo "==> [2/3] downloading dist tarball for ${MP_VERSION}"
    "${DIR}/download-midpoint" "${MP_VERSION}" "dockerfiles/${DIST_FILE}"
    MP_DIST_INFO="$( [ -f "${CTX}/${DIST_FILE}.info" ] && head -n1 "${CTX}/${DIST_FILE}.info" || echo 'N/A' )"
    echo "==> [2/3] building dist image ${DIST_REF}"
    docker build -f "${CTX}/Dockerfile-dist" -t "${DIST_REF}" \
        --build-arg extract_image="${BASE_REF}" \
        --build-arg MP_DIST_FILE="${DIST_FILE}" \
        --build-arg MP_VERSION="${MP_VERSION}" \
        "${CTX}"
else
    echo "==> [2/3] using prebuilt dist ${DIST_REF}"
    MP_DIST_INFO="N/A"
fi

# 3. final
echo "==> [3/3] building final image ${FINAL_REF}"
docker build -f "${CTX}/Dockerfile" -t "${FINAL_REF}" \
    --build-arg base_image="$(split_name "${BASE_REF}")" \
    --build-arg base_image_tag="$(split_tag "${BASE_REF}")" \
    --build-arg dist_image="$(split_name "${DIST_REF}")" \
    --build-arg dist_image_tag="$(split_tag "${DIST_REF}")" \
    --build-arg MP_VERSION="${MP_VERSION}" \
    --build-arg MP_DIST_INFO="${MP_DIST_INFO}" \
    --build-arg RUNTIME_USER="${RUNTIME_USER}" \
    --build-arg H2_DEFAULTS="${H2_DEFAULTS}" \
    "${CTX}"

echo "==> done: ${FINAL_REF}"
