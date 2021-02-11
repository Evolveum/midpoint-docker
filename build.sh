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
       result=$(docker ps -a | grep ${maintainer}/${imagename}:${tag})
       if [ ! -z "$result" ]; then
         echo "Cleaning up ${maintainer}/${imagename}:${tag}..."
         docker rm -f $(docker ps -a | grep ${maintainer}/${imagename}:${tag} | awk '{print $1}')
         docker rmi -f ${maintainer}/${imagename}:${tag}
	 docker image prune -f
         echo "Done"
       fi
       REFRESH="--no-cache --pull"
       echo "Using 'refresh' mode: ${REFRESH}"
       ;;
    h | ?)
       echo "Options: -n skip download"
       echo "         -r refresh mode: uses --no-cache --pull and removes container and image before build"
       exit 0
       ;;
    *)
       echo "Unknown option: ${opt}"
       exit 1
       ;;
    esac
done
if [ ${SKIP_DOWNLOAD} -eq 0 ]; then ./download-midpoint "${tag}" "midpoint-dist-${tag}.tar.gz" || exit 1; fi
docker build ${REFRESH} --network host --tag ${maintainer}/${imagename}:${tag} \
	--build-arg maintainer="${maintainer}" \
	--build-arg imagename="${imagename}" \
	--build-arg SKIP_DOWNLOAD=1 \
	--build-arg MP_DIST_FILE="midpoint-dist-${tag}.tar.gz" \
	--build-arg MP_VERSION=${tag} \
	--build-arg base_image="${base_image}" \
	--build-arg base_image_tag="${base_image_tag}" \
	. || exit 1
if [ ${SKIP_DOWNLOAD} -eq 0 ]; then rm "midpoint-dist-${tag}.tar.gz"; fi
docker image prune -f
echo "---------------------------------------------------------------------------------------"
echo "The midPoint containers were successfully built. To start them, execute the following:"
echo ""
echo "(for image)"
echo ""
echo "$ docker run -p 8080:8080 --name midpoint ${maintainer}/${imagename}:${tag}"
echo ""
echo "(for demo postgresql, clustering, extrepo and simple)"
echo ""
echo "$ cd $(pwd)/demo/[postgresql|clustering|extrepo|simple]"
echo "$ docker-compose up --build"
