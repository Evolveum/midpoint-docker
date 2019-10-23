FROM ubuntu:18.04

MAINTAINER info@evolveum.com

LABEL Vendor="evolveum"
LABEL ImageType="base"
LABEL ImageName="midpoint"
LABEL ImageOS="ubuntu:18.04"
LABEL Version="latest"

# Install Java

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64
RUN sed 's/main$/main universe/' -i /etc/apt/sources.list
RUN apt-get update -y
RUN apt-get install -y openjdk-11-jre tzdata

# Copy scripts

COPY container_files/usr-local-bin/* /usr/local/bin/

RUN chmod 755 /usr/local/bin/setup-timezone.sh \
 && chmod 755 /usr/local/bin/start-midpoint.sh \
 && chmod 755 /usr/local/bin/startup.sh

# Build arguments

ARG MP_VERSION=latest
ARG MP_DIST_FILE=midpoint-dist.tar.gz

ENV MP_DIR /opt/midpoint

RUN mkdir -p ${MP_DIR}/var

COPY container_files/mp-dir/ ${MP_DIST_FILE}* ${MP_DIR}/

# Download and extract Midpoint .war file

ARG SKIP_DOWNLOAD=0

COPY download-midpoint ${MP_DIR}/
COPY common.bash ${MP_DIR}/

RUN if [ "$SKIP_DOWNLOAD" = "0" ];  \
    then apt-get install -y curl \
         && apt-get install libxml2-utils\ 
	 && ./${MP_DIR}/download-midpoint ${MP_VERSION} ${MP_DIST_FILE}; \
    fi

RUN echo 'Extracting midPoint archive...' \
 && tar xzf ${MP_DIR}/${MP_DIST_FILE} -C ${MP_DIR} --strip-components=1

VOLUME ${MP_DIR}/var

# Clean apt-get
RUN apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Repository parameters

ENV REPO_DATABASE_TYPE h2
ENV REPO_JDBC_URL default
ENV REPO_HOST localhost
ENV REPO_PORT default
ENV REPO_DATABASE midpoint
ENV REPO_MISSING_SCHEMA_ACTION create
ENV REPO_UPGRADEABLE_SCHEMA_ACTION stop

# Other parameters

ENV MP_MEM_MAX 2048m
ENV MP_MEM_INIT 1024m
ENV TIMEZONE UTC
ARG MP_JAVA_OPTS

HEALTHCHECK --interval=1m --timeout=30s --start-period=2m CMD /usr/local/bin/healthcheck.sh

EXPOSE 8080

CMD ["/usr/local/bin/startup.sh"]
