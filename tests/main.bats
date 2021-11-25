#!/usr/bin/env bats

load ../common
load ../library

@test "010 Image is present" {
    docker image inspect evolveum/midpoint:${docker_image_tag:-${tag}-${base_image}}
}

@test "020 Check basic components" {
    docker run -i $maintainer/$imagename:${docker_image_tag:-${tag}-${base_image}} \
	find \
		/usr/local/bin/startup.sh \
		/opt/midpoint/var/
}

@test "030 Cleanup before running the tests" {
    docker rm midpoint -v -f || true
}

@test "010 Initialize and start midPoint" {
    MP_CONTAINER_ID=$(docker run -d -p 8180:8080 --name midpoint evolveum/midpoint:${docker_image_tag:-${tag}-${base_image}})
    wait_for_midpoint_start $MP_CONTAINER_ID
}

@test "020 Check health" {
    check_health
}

@test "100 Get 'administrator'" {
    check_health
    get_and_check_object users 00000000-0000-0000-0000-000000000002 administrator
}

@test "110 And and get 'test110'" {
    check_health
    echo "<user><name>test110</name></user>" >/tmp/test110.xml
    add_object users /tmp/test110.xml
    rm /tmp/test110.xml
    search_and_check_object users test110
}

@test "555 Clean up" {
    docker rm midpoint -v -f
}

@test "910 Cleanup before further tests - demo/postgresql" {
    docker ps -a
    cd demo/postgresql ; docker-compose --env-file ../../common.bash down -v ; true
}

@test "911 Cleanup before further tests - demo/clustering" {
    docker ps -a
    cd demo/clustering ; docker-compose --env-file ../../common.bash down -v ; true
}

