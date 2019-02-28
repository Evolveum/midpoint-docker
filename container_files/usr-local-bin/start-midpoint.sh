#!/bin/bash

function check () {
    local VARNAME=$1
    if [ -z ${!VARNAME} ]; then
        echo "*** Couldn't start midPoint: $VARNAME variable is undefined. Please check your Docker composition."
        exit 1
    fi
}

# These variables have reasonable defaults in Dockerfile. So we will _not_ supply defaults here.
# The composer or user has to make sure they are well defined.
check MP_MEM_MAX
check MP_MEM_INIT
check MP_DIR
check REPO_DATABASE_TYPE
check REPO_MISSING_SCHEMA_ACTION
check REPO_UPGRADEABLE_SCHEMA_ACTION
if [ "$REPO_DATABASE_TYPE" != "h2" ]; 
then 
	check MP_KEYSTORE_PASSWORD_FILE
        check REPO_USER
	check REPO_PASSWORD_FILE;	
fi

java -Xmx$MP_MEM_MAX -Xms$MP_MEM_INIT -Dfile.encoding=UTF8 \
       -Dmidpoint.home=$MP_DIR/var \
       -Dmidpoint.repository.database=$REPO_DATABASE_TYPE \
       $(if [ -n "$REPO_USER" ]; then echo "-Dmidpoint.repository.jdbcUsername=$REPO_USER"; fi) \
       $(if [ -n "$REPO_PASSWORD_FILE" ]; then echo "-Dmidpoint.repository.jdbcPassword_FILE=$REPO_PASSWORD_FILE"; fi) \
       -Dmidpoint.repository.jdbcUrl="`$MP_DIR/repository-url`" \
       -Dmidpoint.repository.hibernateHbm2ddl=none \
       -Dmidpoint.repository.missingSchemaAction=$REPO_MISSING_SCHEMA_ACTION \
       -Dmidpoint.repository.upgradeableSchemaAction=$REPO_UPGRADEABLE_SCHEMA_ACTION \
       $(if [ -n "$REPO_SCHEMA_VERSION_IF_MISSING" ]; then echo "-Dmidpoint.repository.schemaVersionIfMissing=$REPO_SCHEMA_VERSION_IF_MISSING"; fi) \
       $(if [ -n "$REPO_SCHEMA_VARIANT" ]; then echo "-Dmidpoint.repository.schemaVariant=$REPO_SCHEMA_VARIANT"; fi) \
       -Dmidpoint.repository.initializationFailTimeout=60000 \
       $(if [ -n "$MP_KEYSTORE_PASSWORD_FILE" ]; then echo "-Dmidpoint.keystore.keyStorePassword_FILE=$MP_KEYSTORE_PASSWORD_FILE"; fi) \
       -Dmidpoint.logging.alt.enabled=true \
       $MP_JAVA_OPTS \
       -jar $MP_DIR/lib/midpoint.war
