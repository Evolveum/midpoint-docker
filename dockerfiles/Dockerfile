ARG MP_VERSION=devel
ARG MP_DIR=/opt/midpoint
ARG MP_DIST_INFO=N/A

# The base image (OS + JDK) and the dist image (midPoint payload) to assemble the final image from.
ARG base_image=registry.evolveum.com/public/midpoint-base
ARG base_image_tag=21-alpine
ARG dist_image=registry.evolveum.com/public/midpoint-dist-snapshot
ARG dist_image_tag=devel
# Runtime user: midPoint 4.11+ runs as the non-root 'midpoint' user; 4.10 and older run as root.
ARG RUNTIME_USER=root
# H2_DEFAULTS=true enables the in-memory H2 demo repository (4.8 and older); 'false' otherwise.
ARG H2_DEFAULTS=false

FROM ${dist_image}:${dist_image_tag} AS dist

FROM ${base_image}:${base_image_tag}

ARG MP_DIR
ARG MP_VERSION
ARG MP_DIST_INFO
ARG RUNTIME_USER
ARG H2_DEFAULTS

LABEL Version="${MP_VERSION}" \
      AppBuildID="${MP_DIST_INFO}"

ENV MP_H2_DEFAULTS=${H2_DEFAULTS}

COPY --chown=${RUNTIME_USER}:${RUNTIME_USER} --from=dist ${MP_DIR} ${MP_DIR}/
COPY --chmod=0755 midpoint-entry.sh /usr/local/bin/midpoint-entry.sh

USER ${RUNTIME_USER}

ENTRYPOINT ["/usr/local/bin/midpoint-entry.sh"]
CMD ["/opt/midpoint/bin/midpoint.sh", "container"]
