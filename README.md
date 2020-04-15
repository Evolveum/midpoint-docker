# MidPoint Docker Images
## Info
[MidPoint](https://github.com/Evolveum/midpoint) is open identity & organization management and governance platform which uses Identity Connector Framework (ConnId) and leverages Spring framework. It is a Java application deployed as a stand-alone server process. This image is based on official Ubuntu 18.04 image and deploys latest MidPoint version.

## Tags:
- `latest`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker)
- `4.1`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/4.1)
- `4.0.2`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/4.0.2)
- `4.0.1`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/4.0.1)
- `4.0`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/4.0)
- `3.9`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/3.9)
- `3.8`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/3.8)
- `3.7.1`[(midpoint/Dockerfile)](https://github.com/Evolveum/midpoint-docker/tree/3.7.1)

## Download image:
- download image without building:
```
$ docker pull evolveum/midpoint
```

## Build from git repository  
- clone git repository:
```
$ git clone https://github.com/Evolveum/midpoint-docker.git
$ cd midpoint-docker
```
- build:
```
$ docker build -t evolveum/midpoint ./
```
- or
```
$ ./build.sh
```
You can then continue with image or one of demo composition, e.g. postgresql or clustering one.

## Launch:
- run image on port 8080:
```
$ docker run -p 8080:8080 --name midpoint evolveum/midpoint
```
- run image on port 8080 with increased heap size:
```
$ docker run -p 8080:8080 -e MP_MEM_MAX='4096M' -e MP_MEM_INIT='4096M' --name midpoint evolveum/midpoint
```
- run one of demo composition, e.g. postgresql:
```
$ cd demo/postgresql/
$ docker-compose up --build
```

## Access MidPoint:
- URL: http://127.0.0.1:8080/midpoint
- username: Administrator
- password: 5ecr3t

## Documentation
Please see [Dockerized midPoint](https://wiki.evolveum.com/display/midPoint/Dockerized+midPoint) wiki page.

