##
FROM openjdk:8-jdk-alpine

MAINTAINER info@evolveum.com

ENV MP_VERSION 3.8
ENV MP_DIR /opt/midpoint
ENV XMX 3072M
ENV XMS 3072M

RUN mkdir -p ${MP_DIR}/var \
 && wget https://evolveum.com/downloads/midpoint/${MP_VERSION}/midpoint-${MP_VERSION}-dist.tar.gz -P ${MP_DIR} \
 && echo 'Extracting midPoint archive...' \
 && tar xzf ${MP_DIR}/midpoint-${MP_VERSION}-dist.tar.gz -C ${MP_DIR} --strip-components=1
 && wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.12.tar.gz
 && tar xzf ./mysql-connector-java-8.0.12.tar.gz
 && cp ./mysql-connector-java-8.0.12/mysql-connector-java-8.0.12.jar ${MP_DIR}/lib/

COPY ./config.xml ${MP_DIR}/var/config.xml

CMD ["/bin/sh", "-c", "java -Xmx$XMX -Xms$XMS -Dfile.encoding=UTF8 -Dmidpoint.home=$MP_DIR/var -jar $MP_DIR/lib/midpoint.war"]
