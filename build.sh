#!/bin/bash

cd "$(dirname "$0")"
source common.bash

SKIP_DOWNLOAD=0
REFRESH=""
while getopts "nhr?" opt; do
    case $opt in
    n)
       SKIP_DOWNLOAD=1
       ;;
    r)
       result=$(docker ps -a | grep $maintainer/$imagename:$tag)
       if [ ! -z "$result" ]; then
         echo "Cleaning up $maintainer/$imagename:$tag..."
         docker rm -f $(docker ps -a | grep $maintainer/$imagename:$tag | awk '{print $1}')
         docker rmi -f $maintainer/$imagename:$tag
         echo "Done"
       fi
       REFRESH="--no-cache --pull"
       echo "Using 'refresh' mode: $REFRESH"
       ;;
    h | ?)
       echo "Options: -n skip download"
       echo "         -r refresh mode: uses --no-cache --pull and removes container and image before build"
       exit 0
       ;;
    *)
       echo "Unknown option: $opt"
       exit 1
       ;;
    esac
done
if [ "$SKIP_DOWNLOAD" = "0" ]; then ./download-midpoint || exit 1; fi
docker build $REFRESH --network host --tag $maintainer/$imagename:$tag --build-arg maintainer=$maintainer --build-arg imagename=$imagename --build-arg SKIP_DOWNLOAD=1 . || exit 1
echo "---------------------------------------------------------------------------------------"
echo "The midPoint containers were successfully built. To start them, execute the following:"
echo ""
echo "(for image)"
echo ""
echo "$ docker run -p 8080:8080 --name midpoint evolveum/midpoint:$tag"
echo ""
echo "(for demo postgresql or clustering)"
echo ""
echo "$ cd $(pwd)/demo/[postgresql|clustering]"
echo "$ docker-compose up --build"
