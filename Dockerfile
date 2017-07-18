FROM tomcat:8.0.44-jre8
ENV JAVA_OPTS="-server -Xms256m -Xmx512m -Dmidpoint.home=/var/opt/midpoint/ -Djavax.net.ssl.trustStore=/var/opt/midpoint/keystore.jceks -Djavax.net.ssl.trustStoreType=jceks"

MAINTAINER info@evolveum.com

ENV version 3.6

RUN apt-get update \
&& apt-get -y install wget

RUN wget https://evolveum.com/downloads/midpoint/${version}/midpoint-${version}-dist.tar.bz2

RUN echo 'Extracting midPoint archive...' \
&& tar xjf midpoint-${version}-dist.tar.bz2 \
&& rm -f midpoint-${version}-dist.tar.bz2

RUN cp midpoint-${version}/war/midpoint.war /usr/local/tomcat/webapps \
&& rm -rf midpoint-${version}

CMD ["catalina.sh", "run"]