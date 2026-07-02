#!/bin/sh
set -e

if [ -e /opt/midpoint/var ] && [ ! -w /opt/midpoint/var ]; then
    cat >&2 <<'EOF'
ERROR: /opt/midpoint/var is not writable by the midpoint user (UID 1000).

midPoint 4.11+ runs as the unprivileged `midpoint` user (UID 1000). Two common
cases lead here:

  1. Fresh install on Kubernetes with a PersistentVolumeClaim - the mounted
     PVC defaults to root:root ownership (CSI driver default), so the midpoint
     user cannot write to it. Set `securityContext.fsGroup: 1000` on the pod
     and k8s will relabel the volume group on mount.

  2. In-place upgrade from a midPoint <4.11 image that ran as root - the
     persistent data on disk is still owned by root. Either set
     `securityContext.fsGroup: 1000` (k8s recursively relabels; fine for small
     data) or run a one-time chown via an init container or on the host.
EOF
    exit 1
fi

if [ "${MP_H2_DEFAULTS:-false}" = "true" ] && [ -z "${MP_SET_midpoint_repository_database:-}" ]; then
    export MP_SET_midpoint_repository_database=h2
    export MP_SET_midpoint_repository_jdbcUrl='jdbc:h2:tcp://localhost:5437/./midpoint;DB_CLOSE_ON_EXIT=FALSE;LOCK_MODE=1;LOCK_TIMEOUT=100;MAX_LENGTH_INPLACE_LOB=10240;NON_KEYWORDS=VALUE'
    export MP_SET_midpoint_repository_hibernateHbm2ddl=none
    export MP_SET_midpoint_repository_initializationFailTimeout=60000
    export MP_SET_midpoint_repository_missingSchemaAction=create
    export MP_SET_midpoint_repository_upgradeableSchemaAction=stop
fi

if [ "$#" -eq 0 ]; then
    set -- /opt/midpoint/bin/midpoint.sh container
fi

exec "$@"
