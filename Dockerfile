ARG MP_DIR=/opt/midpoint

FROM ubuntu:18.04

ARG MP_DIR
ARG MP_VERSION=latest
ARG MP_DIST_FILE=midpoint-dist.tar.gz
ARG SKIP_DOWNLOAD=0

COPY download-midpoint common.bash ${MP_DIST_FILE}* ${MP_DIR}/

RUN if [ "$SKIP_DOWNLOAD" = "0" ];  \
    then echo "Installing necessary packages to download,,," \
	 && apt-get update -y && apt-get install -y curl libxml2-utils \
	 && echo "Downloading the application..." \
         && ${MP_DIR}/download-midpoint ${MP_VERSION} ${MP_DIST_FILE}; \
    else \
	 echo "Download of th eapplication has been skipped..."; \
    fi

RUN echo 'Extracting midPoint archive...' \
      && tar xzf ${MP_DIR}/${MP_DIST_FILE} -C ${MP_DIR} --strip-components=1

RUN echo "Cleaning up temporary files..." \
      && rm -f  ${MP_DIR}/${MP_DIST_FILE}* ${MP_DIR}/download-midpoint ${MP_DIR}/common.bash

FROM ubuntu:18.04

ARG MP_DIR

MAINTAINER info@evolveum.com

LABEL Vendor="evolveum"
LABEL ImageType="base"
LABEL ImageName="midpoint"
LABEL ImageOS="ubuntu:18.04"
LABEL Version="latest"

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
  MP_DIR=${MP_DIR} \
  REPO_DATABASE_TYPE=h2 \
  REPO_JDBC_URL=default \
  REPO_HOST=localhost \
  REPO_PORT=default \
  REPO_DATABASE=midpoint \
  REPO_MISSING_SCHEMA_ACTION=create \
  REPO_UPGRADEABLE_SCHEMA_ACTION=stop \
  MP_MEM_MAX=2048m \
  MP_MEM_INIT=1024m \
  TZ=UTC

COPY --from=0 ${MP_DIR} ${MP_DIR}

COPY container_files/usr-local-bin/* /usr/local/bin/
COPY container_files/mp-dir/ ${MP_DIR}/

RUN sed 's/main$/main universe/' -i /etc/apt/sources.list \
  && apt-get update -y \
  && apt-get install -y openjdk-11-jre tzdata \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && chmod 755 /usr/local/bin/* \
  && mkdir -p ${MP_DIR}/var

VOLUME ${MP_DIR}/var

HEALTHCHECK --interval=1m --timeout=30s --start-period=2m CMD /usr/local/bin/healthcheck.sh

EXPOSE 8080

CMD ["/usr/local/bin/startup.sh"]
