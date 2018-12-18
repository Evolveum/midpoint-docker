FROM openjdk:8-jdk-alpine

MAINTAINER info@evolveum.com

ENV MP_VERSION 3.9
ENV MP_DIR /opt/midpoint
ENV XMX 2048M
ENV XMS 2048M

RUN mkdir -p ${MP_DIR}/var \
 && wget https://evolveum.com/downloads/midpoint/${MP_VERSION}/midpoint-${MP_VERSION}-dist.tar.gz -P ${MP_DIR} \
 && echo 'Extracting midPoint archive...' \
 && tar xzf ${MP_DIR}/midpoint-${MP_VERSION}-dist.tar.gz -C ${MP_DIR} --strip-components=1

CMD ["/bin/sh", "-c", "java -Xmx$XMX -Xms$XMS -Dfile.encoding=UTF8 -Dmidpoint.home=$MP_DIR/var -jar $MP_DIR/lib/midpoint.war"]
