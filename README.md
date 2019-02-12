# midPoint: the Identity Governance and Administration tool
## Info
MidPoint is open identity & organization management and governance platform which uses Identity Connector Framework (ConnId) and leverages Spring framework. It is a Java application deployed as a stand-alone server process. This image is based on official OpenJDK version 8 image which runs on Alpine Linux and deploys latest MidPoint version 3.7.1.

## Tags:
- `latest`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker)
- `3.8`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/3.8)
- `3.7.1`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/3.7.1)

## Launch Container:
- download:
```
docker pull evolveum/midpoint
```
- run on port 8080:
```
docker run -p 8080:8080 --name midpoint evolveum/midpoint
```
- run on port 8080 with increased heap size:
```
docker run -p 8080:8080 -e XMX='4096M' -e XMS='4096M' --name bigger_midpoint evolveum/midpoint
```

## Access MidPoint:
- URL: http://127.0.0.1:8080/midpoint
- username: Administrator
- password: 5ecr3t

## Admin access:
- shell:
```
docker exec -it midpoint /bin/sh
```
- container logs:
```
docker logs midpoint
```
- midPoint home: /opt/midpoint/var/
- log files: /opt/midpoint/var/log
