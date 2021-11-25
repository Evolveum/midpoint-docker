#!/usr/bin/env bats

load ../../../common
load ../../../library

@test "000 Cleanup before running the tests" {
    run docker-compose --env-file ../../common.bash -f docker-compose-tests.yml down -v
}

@test "010 Initialize and start midPoint" {
    docker-compose --env-file ../../common.bash -f docker-compose-tests.yml up -d
    wait_for_midpoint_start postgresql-midpoint_server-1
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

@test "300 Check repository preserved between restarts" {
    check_health

    echo "Creating user test300 and checking its existence"
    echo "<user><name>test300</name></user>" >/tmp/test300.xml
    add_object users /tmp/test300.xml
    rm /tmp/test300.xml
    search_and_check_object users test300

    echo "Bringing the containers down"
    docker-compose -f docker-compose-tests.yml down

    echo "Re-creating the containers"
    docker-compose --env-file ../../common.bash -f docker-compose-tests.yml up --no-start
    docker-compose --env-file ../../common.bash -f docker-compose-tests.yml start
    wait_for_midpoint_start postgresql-midpoint_server-1

    echo "Searching for the user again"
    search_and_check_object users test300
}

@test "350 Test DB schema version check" {
    echo "status before test..."
    docker ps -a
    PGPASSWORD=WJzesbe3poNZ91qIbmR7 && docker exec postgresql-midpoint_data-1 psql -U midpoint midpoint -c "\dt"

    echo "Removing version information from m_global_metadata"
    PGPASSWORD=WJzesbe3poNZ91qIbmR7 && docker exec postgresql-midpoint_data-1 psql -U midpoint midpoint -c "drop table m_global_metadata"

    echo "Bringing the containers down"
    docker-compose -f docker-compose-tests.yml down

    echo "Re-creating the containers"
    docker-compose --env-file ../../common.bash -f docker-compose-tests.yml up -d

    wait_for_log_message postgresql-midpoint_server-1 "Database schema is not compatible with the executing code; however, an upgrade path is available."
}

#@test "360 Test DB schema upgrade" {
#    echo "Stopping midpoint_server container"
#    docker stop postgresql-midpoint_server-1
#
#    echo "Installing empty 3.8 repository"
#    PGPASSWORD=WJzesbe3poNZ91qIbmR7 && docker exec -it postgresql-midpoint_data-1 psql -U midpoint template1 -c "DROP DATABASE midpoint"
#    curl https://raw.githubusercontent.com/Evolveum/midpoint/v3.8/config/sql/_all/sql/_all/postgresql-3.8-all.sql > /tmp/create-3.8.sql
#    docker cp /tmp/create-3.9-utf8mb4.sql postgresql-midpoint_data-1:/tmp/create-3.8.sql
#    PGPASSWORD=WJzesbe3poNZ91qIbmR7 && docker exec -it postgresql-midpoint_data-1 psql -U midpoint template1 -c "CREATE DATABASE midpoint WITH OWNER = midpoint ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8' CONNECTION LIMIT = -1;"
#    docker exec postgresql-midpoint_data-1 bash -c "PGPASSWORD=WJzesbe3poNZ91qIbmR7 && psql -U midpoint -d  midpoint < /tmp/create-3.8.sql"
#
#    echo "Bringing the containers down"
#    docker-compose down
#
#    echo "Re-creating the containers"
#    env REPO_SCHEMA_VERSION_IF_MISSING=3.9 REPO_UPGRADEABLE_SCHEMA_ACTION=upgrade REPO_SCHEMA_VARIANT=utf8mb4 docker-compose up -d
#
#    wait_for_log_message postgresql-midpoint_server-1 "Schema was successfully upgraded from 3.8 to 3.9 using script 'postgresql-upgrade-3.8-3.9-utf8mb4.sql'"
#    wait_for_midpoint_start postgresql-midpoint_server-1
#}

@test "999 Clean up" {
    docker-compose -f docker-compose-tests.yml down -v
}
