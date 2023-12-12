ARG MP_VERSION=latest
ARG MP_DIR=/opt/midpoint
ARG MP_DIST_FILE=midpoint-dist.tar.gz
ARG MP_DIST_INFO=N/A
ARG SKIP_DOWNLOAD=0
ARG maintainer=evolveum
ARG imagename=midpoint
ARG JAVA_VERSION=17

### values for Ubuntu based image ###
#ARG base_image=ubuntu
#ARG base_image_tag=22.04
####################################

### values for Rocky linux based image ###
ARG base_image=rockylinux
ARG base_image_tag=9.3
#####################################

### values for Alpine based image ###
#ARG base_image=alpine
#ARG base_image_tag=latest
#####################################

FROM ${base_image}:${base_image_tag}

ARG base_image
ARG MP_VERSION
ARG MP_DIR
ARG MP_DIST_FILE
ARG SKIP_DOWNLOAD

RUN if [ "${base_image}" = "ubuntu" ]; \
  then apt-get update -y && apt-get install -y curl libxml2-utils ; \
  else if [ "${base_image}" = "alpine" ]; \
  then apk --update add --no-cache libxml2-utils curl bash ; \
  fi ; fi

COPY download-midpoint map_midpoint-docker.csv common.bash ${MP_DIST_FILE}* ${MP_DIR}/

RUN if [ "${SKIP_DOWNLOAD}" = "0" ]; \
  then chmod 755 ${MP_DIR}/download-midpoint && \
       ${MP_DIR}/download-midpoint ${MP_VERSION} ${MP_DIST_FILE} ; \
  fi ; \
  tar -xzC ${MP_DIR} -f ${MP_DIR}/${MP_DIST_FILE} --strip-components=1 ; \
  rm -f ${MP_DIR}/${MP_DIST_FILE}* ${MP_DIR}/download-midpoint ${MP_DIR}/map_midpoint-docker.csv ${MP_DIR}/common.bash

##### 2022/05/02 - "reaction" to adding jar package to dist archive ######
# Once both jar and war is present the only jar is needed. During transition perion the
# symlink is created to prevent the fails because of not updated starting script
# ... docker related file have a little bit different lifecycle than midpoint files ...
##########################################################################
RUN if [ -e ${MP_DIR}/lib/midpoint.jar ]; \
  then ln -sf midpoint.jar ${MP_DIR}/lib/midpoint.war ; fi

FROM ${base_image}:${base_image_tag}

ARG MP_DIR
ARG MP_VERSION
ARG MP_DIST_INFO
ARG base_image
ARG base_image_tag
ARG maintainer
ARG imagename
ARG JAVA_VERSION

LABEL Vendor="${maintainer}"
LABEL ImageType="base"
LABEL ImageName="${imagename}"
LABEL ImageOS="${base_image}:${base_image_tag}"
LABEL Version="${MP_VERSION}"
LABEL AppBuildID="${MP_DIST_INFO}"
LABEL org.opencontainers.image.authors="info@evolveum.com"

ENV MP_SET_midpoint_repository_database=h2 \
 MP_SET_midpoint_repository_jdbcUrl=jdbc:h2:tcp://localhost:5437/midpoint \
 MP_SET_midpoint_repository_hibernateHbm2ddl=none \
 MP_SET_midpoint_repository_initializationFailTimeout=60000 \
 MP_SET_midpoint_repository_missingSchemaAction=create \
 MP_SET_midpoint_repository_upgradeableSchemaAction=stop \
 MP_SET_file_encoding=UTF8 \
 MP_SET_midpoint_logging_alt_enabled=true \
 MP_MEM_MAX=2048m \
 MP_MEM_INIT=1024m \
 TZ=UTC \
 MP_DIR=${MP_DIR}

COPY container_files/usr-local-bin/* /usr/local/bin/

COPY --from=0 ${MP_DIR} ${MP_DIR}/

RUN if [ "${base_image}" = "ubuntu" ]; \
  then sed 's/main$/main universe/' -i /etc/apt/sources.list && \
       apt-get update -y && \
       apt-get install -y openjdk-${JAVA_VERSION}-jre-headless tzdata curl && \
       apt-get clean && \
       rm -rf /var/lib/apt/lists/*/tmp/* /var/tmp/* ; \
  else if [ "${base_image}" = "rockylinux" ]; \
  then dnf update -y && dnf install -y java-${JAVA_VERSION}-openjdk-headless tzdata bash which && dnf clean all -y ; \
  else apk --update add --no-cache openjdk${JAVA_VERSION}-jre-headless curl libxml2-utils tzdata bash fontconfig ttf-dejavu ; \
  fi ; fi ; \
  if [ ! -e "${MP_DIR}/bin/setenv.sh" ] ; then echo "#!/usr/bin/env bash" > "${MP_DIR}/bin/setenv.sh" ; fi ; \
  echo -n "export JAVA_HOME=" >> "${MP_DIR}/bin/setenv.sh" ; \
  find /usr/lib/jvm -maxdepth 1 -name "*openjdk*" -name "*${JAVA_VERSION}*" -type d | head -1 >> ${MP_DIR}/bin/setenv.sh ; \
  echo "[ \$(echo \${PATH} | grep -c openjdk) -eq 0 ] && PATH=\${PATH}:\${JAVA_HOME}/bin" >>${MP_DIR}/bin/setenv.sh

VOLUME ${MP_DIR}/var

HEALTHCHECK --interval=1m --timeout=30s --start-period=2m CMD /usr/local/bin/healthcheck.sh

EXPOSE 8080

CMD [ "/opt/midpoint/bin/midpoint.sh", "container" ]

RUN echo "fix for starting midpoint around release 4.2..." ; \
  if [ $(grep -c "\-cp \"\${BASE_DIR}/lib/midpoint.war\"" ${MP_DIR}/bin/midpoint.sh ) -eq 1 ] ; then \
  sed -i "/^[[:space:]]*-jar \"\${BASE_DIR}\/lib\/midpoint.war\"/a \ \ \ \ -Dloader.path=\"WEB-INF/classes,WEB-INF/lib,WEB-INF/lib-provided,${MP_DIR}/lib/\" org.springframework.boot.loader.PropertiesLauncher \\\\" /usr/local/bin/midpoint.sh ; \
  sed -i "s/^[[:space:]]*-jar \"\${BASE_DIR}\/lib\/midpoint.war\"/    -cp \"\${BASE_DIR}\/lib\/midpoint.war\"/g" /usr/local/bin/midpoint.sh ; \
  echo "\"old\" -cp style start found and updated..." ; \
  fi ; \
  echo "end of fix check..." ; \
  if [ $(grep -c "container" ${MP_DIR}/bin/midpoint.sh) -eq 0 ]; then \
  cp /usr/local/bin/midpoint.sh ${MP_DIR}/bin/midpoint.sh && echo "midpoint.sh file replaced" ; fi 

