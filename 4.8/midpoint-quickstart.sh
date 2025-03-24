#!/usr/bin/env bash
# Portions Copyright (C) 2017-2024 Evolveum and contributors
#
# This work is dual-licensed under the Apache License 2.0
# and European Union Public License. See LICENSE file for details.
#
# Script should run on bash 3.2 to allow OS X usage.

#########
# Take the base directory for the sctructure from the script location
#########

midPoint_script="${0}"

midPoint_base_dir="$(cd "$(dirname "$0")" && pwd -P)"
midPoint_home_dir="midpoint-home"

midPoint_uid=$(id -u)
midPoint_gid=$(id -g)
midPoint_docker_membership=$(groups | grep -c  -w "docker")
midPoint_env_exec=""
midPoint_debug=0
midPoint_foreground=0
midPoint_port=8080

midPoint_image_name="evolveum/midpoint"
midPoint_image_ver=4.8.7
midPoint_image_suffix="-alpine"

if [ -e ${midPoint_home_dir}/init_pw ]
then
	midPoint_initPw="$(cat ${midPoint_home_dir}/init_pw)"
else
	midPoint_initPw="$(dd if=/dev/urandom bs=64 count=4 2>/dev/null | base64 -w 0 | sed "s/^.*\([A-Za-z0-9]\{7\}\)\([A-Z]\).*\([a-z]\).*\([0-9]\).*/\1\2\3\4/")"
	[ -e ${midPoint_home_dir} ] && echo -n "${midPoint_initPw}" > ${midPoint_home_dir}/init_pw
fi

midPoint_subDirectories="post-initial-objects connid-connectors lib"

#########
# Parsing of the provided parameters
#########
preserved_args=""

while [ "${1:0:1}" == "-" ]
do
	preserved_args="${preserved_args} ${1}"

	case ${1:1} in
# [help_o] -h .t..t..t. help - show available option(s) [this information]
# [help_o] 
		h)	# print out the help - looking for the [help_X] "tagged" comments
			echo
			echo "${0} [options] [command]"
			echo
			echo "Available commands:"
			grep "#[ ]\[help_c\]" $0 | sed "s/.*# \[help_c\] \(.*\)/\1/;s/\.t\./\t/g"
			echo "Available options :"
			grep "#[ ]\[help_o\]" $0 | sed "s/.*# \[help_o\] \(.*\)/\1/;s/\.t\./\t/g"
			echo "Exit codes:"
			grep "#[ ]\[help_e\]" $0 | sed "s/.*# \[help_e\] \(.*\)/\1/;s/\.t\./\t/g" | sort -h | uniq
			echo
			echo "Current Values (default or already overwritten by arguments) :"
########
# Dynamic init PW has been implemented since 4.8.1
########
			if [ "${midPoint_image_ver}" == "4.8" ]
			then
				midPoint_initPw="5ecr3t"
			fi

			echo -en " debug\t\t: "
			[ ${midPoint_debug} -eq 0 ] && echo "No" || echo "Yes"
			echo -en " foreground\t: "
			[ ${midPoint_foreground} -eq 0 ] && echo "No" || echo "Yes"
			echo -e " base directory\t: ${midPoint_base_dir}"
			echo -e " home directory\t: ${midPoint_home_dir}"
			echo -e " subdirectories\t: ${midPoint_subDirectories[@]}"
			echo -e " admin init PW\t: ${midPoint_initPw}"
			echo -e " User ID\t: ${midPoint_uid}"
			echo -e " Group ID\t: ${midPoint_gid}"
			echo -e " Port\t\t: ${midPoint_port} ( http://localhost:${midPoint_port}/midpoint/ )"
			echo -e " Image name\t: ${midPoint_image_name}"
			echo -e " Image version\t: ${midPoint_image_ver}"
			echo -e " Image suffix\t: ${midPoint_image_suffix}"
			echo -e "  Image : ${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}"
# [help_e] 0 .t. Normal exit (expected operation)			
			exit 0
			;;
# [help_o] -debug .t..t..t. Debug (show operation output for the troubleshooting purpose)
# [help_o] 
		debug)
			midPoint_debug=1
			;;
# [help_o] -fg .t..t..t. Foreground (keep attached / not starting on background)
# [help_o] 
		fg)
			midPoint_foreground=1
			;;
# [help_o] -base <base_dir> .t. base directory (by default derived from the script location)
# [help_o] .t. Used to calculate the location of the files
# [help_o] 
		base)
			preserved_args="${preserved_args} ${2}"
			midPoint_base_dir=${2}
			shift
			;;
# [help_o] -initpw <init_password>.t. Initial administrator password
# [help_o] .t. Initial password for the first run. This is not used for the password change once the user is created.
# [help_o] 
		initpw)
			preserved_args="${preserved_args} ${2}"
			midPoint_initPw="${2}"
			shift
			;;
# [help_o] -home <home_dir> .t. home directory (related to base_dir)
# [help_o] .t. The name of the directory - the root of the direcrtory structure for the midpoint instance
# [help_o] 
		home)
			preserved_args="${preserved_args} ${2}"
			midPoint_home_dir=${2}
			shift
			;;
# [help_o] -subdir <directories> .t. comma separated list of sub-directories to be created
# [help_o] 
		subdir)
			preserved_args="${preserved_args} ${2}"
			midPoint_subDirectories="${2}"
			shift
			;;
# [help_o] -uid <uid> .t..t. User ID for the processes in the container
# [help_o] .t. Default value is taken from the currently logged user (current session)
# [help_o] 
		uid)
			preserved_args="${preserved_args} ${2}"
			midPoint_uid=${2}
			shift
			;;
# [help_o] -gid <gid> .t..t. Group ID for the processes in the container
# [help_o] .t. Default value is taken from the currently logged user (current session)
# [help_o] 
		gid)
			preserved_args="${preserved_args} ${2}"
			midPoint_gid=${2}
			shift
			;;
# [help_o] -port <port> .t..t. TCP port used for the forwarding.
# [help_o] .t. TCP port used for redirect the communication. ( http://localhost:<port>/midpoint/ )
# [help_o] 
		port)
			preserved_args="${preserved_args} ${2}"
			midPoint_port=${2}
			shift
			;;
# [help_o] -name <img_name> .t. Image name (without tag)
# [help_o] .t. Used to construct final image name for the configuration.
# [help_o] 
		name)
			preserved_args="${preserved_args} ${2}"
			midPoint_image_name=${2}
			shift
			;;
# [help_o] -ver <img_version> .t. Image version
# [help_o] .t. Used to construct final image name for the configuration.
# [help_o] 
		ver)
			preserved_args="${preserved_args} ${2}"
			midPoint_image_ver=${2}
			shift
			;;
# [help_o] -suffix <img_v_suffix> .t. Image version suffix
# [help_o] .t. Used to construct final image name for the configuration.
# [help_o] 
		suffix)
			preserved_args="${preserved_args} ${2}"
			midPoint_image_suffix=${2}
			shift
			;;
# [help_o] -exec <env_exec_cmd> .t. Command to run / control env.
# [help_o] .t. Default value is *docker* or *sudo docker* in case the used is not member of the docker group.
# [help_o] 
		exec)
			preserved_args="${preserved_args} ${2}"
			midPoint_env_exec="${2}"
			shift
			;;
	esac
	shift
done

#########
# The check if the parameter has been provided
#########

if [[ -z ${1:-} ]]; then
  ${0} ${preserved_args} -h
# [help_e] 1 .t. No command has been requested.
  exit 1
fi

########
# Dynamic init PW has been implemented since 4.8.1
########
if [ "${midPoint_image_ver}" == "4.8" ]
then
	midPoint_initPw="5ecr3t"
fi

#########
# command to execute
#########

if [ "${midPoint_env_exec}" == "" ]
then
	if [ ${midPoint_docker_membership:-0} -eq 1 ]
	then
		midPoint_env_exec="docker"
	else
		midPoint_env_exec="sudo docker"
	fi
fi


#########
# Function definition - it will be called as needed from the following code
#########


# Check the directory and create in case it is not exists
function env_checkDir {
        if [ ${#1} -lt 10 ]
        then
                echo "SKIP - the path \"${1}\" is too short." >&2
# [help_e] 101 .t. Too short path to process (basic "security" check)
                exit 101
        fi
	[ ${midPoint_debug} -gt 0 ] && echo "Test for the directory \"${1}\" existence..." >&2
	if [ ! -d "${1}" ]
	then
		[ ${midPoint_debug} -gt 0 ] && echo "The directory \"${1}\" doesn't exist." >&2
		echo "Creating the directory \"${1}\"."
		mkdir "${1}"
		exitCode=$?
                if [ ${exitCode} -ne 0 ]
                then
			echo "Can't create the directory \"${1}\" [ mkdir exitcode is ${exitCode} ]." >&2
# [help_e] 2 .t. Can't create the directory.
			exit 2
		fi
	else
		[ ${midPoint_debug} -gt 0 ] && echo "The directory \"${1}\" exists..." >&2
	fi
}

# Process list of directories to check and create if not exists
function init_env {
	[ "${1:-}" != "silent" ] && echo "Starting the Inicialization process..."
	env_checkDir "${midPoint_base_dir}/${midPoint_home_dir}"
	for dirToProcess in ${midPoint_subDirectories}
	do
		env_checkDir "${midPoint_base_dir}/${midPoint_home_dir}/${dirToProcess}"
	done

	[ ! -e ${midPoint_base_dir}/${midPoint_home_dir}/init_pw ] && echo -n "${midPoint_initPw}" > ${midPoint_base_dir}/${midPoint_home_dir}/init_pw
	[ "${1:-}" != "silent" ] && echo "Inicialization done."
}

function env_remdir {
	if [ ${#1} -lt 10 ]
        then
                echo "SKIP - the path \"${1}\" is too short." >&2
# [help_e] 101 .t. Too short path to process (basic "security" check)
                exit 101
        fi
	if [ -d "${1}" ]
        then
		echo "Removing \"${1}\""
		rm -rf "${1}"
		exitCode=$?
		if [ ${exitCode} -ne 0 ]
		then
			echo "Can't remove the directory \"${1}\" [ rm exitcode is ${exitCode} ]." >&2
# [help_e] 3 .t. Can't remove the directory.
			exit 3
		fi
	fi
}

function clean_env {
	[ "${1:-}" != "silent" ] && echo "Starting the Clean up process..."
	getDockerCompose | ${midPoint_env_exec} compose -f - down -v
	env_remdir "${midPoint_base_dir}/${midPoint_home_dir}" ${1:-}
	[ "${1:-}" != "silent" ] && echo "Clean up process done."
}

function getDockerCompose {

	cat <<EOF
version: "3.3"

services:
  midpoint_data:
    image: postgres:16-alpine
    environment:
     - POSTGRES_PASSWORD=db.secret.pw.007
     - POSTGRES_USER=midpoint
     - POSTGRES_INITDB_ARGS=--lc-collate=en_US.utf8 --lc-ctype=en_US.utf8
    networks:
     - net
    volumes:
     - midpoint_data:/var/lib/postgresql/data

  data_init:
    image: ${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}
    command: >
      bash -c "
      cd /opt/midpoint ;
      bin/midpoint.sh init-native ;
      echo ' - - - - - - ' ;
      bin/ninja.sh -B info >/dev/null 2>/tmp/ninja.log ;
      grep -q \"ERROR\" /tmp/ninja.log && (
      bin/ninja.sh run-sql --create --mode REPOSITORY  ;
      bin/ninja.sh run-sql --create --mode AUDIT
      ) ||
      echo -e '\\n Repository init is not needed...' ;
      "
    user: "${midPoint_uid}:${midPoint_gid}"
    depends_on:
     - midpoint_data
    environment:
     - MP_SET_midpoint_repository_jdbcUsername=midpoint
     - MP_SET_midpoint_repository_jdbcPassword=db.secret.pw.007
     - MP_SET_midpoint_repository_jdbcUrl=jdbc:postgresql://midpoint_data:5432/midpoint
     - MP_SET_midpoint_repository_database=postgresql
     - MP_INIT_CFG=/opt/midpoint/var
    networks:
     - net
    volumes:
     - ${midPoint_base_dir}/${midPoint_home_dir}:/opt/midpoint/var

  midpoint_server:
    image: ${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}
    depends_on:
      data_init:
        condition: service_completed_successfully
      midpoint_data:
        condition: service_started
    command: [ "/opt/midpoint/bin/midpoint.sh", "container" ]
    user: "${midPoint_uid}:${midPoint_gid}"
    ports:
      - ${midPoint_port}:8080
    environment:
     - MP_SET_midpoint_repository_jdbcUsername=midpoint
     - MP_SET_midpoint_repository_jdbcPassword=db.secret.pw.007
     - MP_SET_midpoint_repository_jdbcUrl=jdbc:postgresql://midpoint_data:5432/midpoint
     - MP_SET_midpoint_repository_database=postgresql
     - MP_SET_midpoint_administrator_initialPassword=${midPoint_initPw}
     - MP_UNSET_midpoint_repository_hibernateHbm2ddl=1
     - MP_NO_ENV_COMPAT=1
    networks:
     - net
    volumes:
     - ${midPoint_base_dir}/${midPoint_home_dir}:/opt/midpoint/var

networks:
  net:
    driver: bridge

volumes:
  midpoint_data:
EOF
}

#########
# Command processing
#########

case ${1} in
# [help_c] init .t..t. Init environment
# [help_c] .t. check and create the directory structure for midpoint home if needed
# [help_c] 
	init)
		shift
		init_env "${@}"
		;;
# [help_c] clean .t..t. Clean environment
# [help_c] .t. delete directory structure for midpoint home
# [help_c] 
	clean)
		shift
		clean_env "${@}"
		;;
# [help_c] reset .t..t. Reset environment
# [help_c] .t. delete and re-create directory structure for midpoint home
# [help_c] 
	reset)
		shift
		clean_env "${@}"
		echo
		init_env "${@}"
		;;
# [help_c] up / start .t. Start the environment
# [help_c] .t. Init the environment (if neede) and start it up
# [help_c] 
	up|start)
		init_env
		if [ ${midPoint_foreground} -eq 1 ]
		then
			getDockerCompose | ${midPoint_env_exec} compose -f - up
		else
			getDockerCompose | ${midPoint_env_exec} compose -f - up --wait
			dockerExitCode=$?
			if [ ${dockerExitCode} -eq 0 ]
			then
				echo "MidPoint has started..."
				echo "To access the WEB GUI go to http://localhost:${midPoint_port}/midpoint/ ."
				echo " Username : administrator"
				echo " Password : ${midPoint_initPw} (if not changed yet - init Password)"
			else
				echo "..."
				tail -50 ${midPoint_home_dir}/log/midpoint.log
				echo
				echo "Midpoint did not start properly (e.g. version mismatch). This should not happend, try to clean and re-init the midPoint environment."
			fi
		fi
		;;
# [help_c] down .t..t. Shutdown the environment.
# [help_c] .t. Stop environemnt, remove the container objects except volumes and data on "external" filesystem.
# [help_c] 
	down)
                getDockerCompose | ${midPoint_env_exec} compose -f - down
                ;;
# [help_c] clean-db .t. Remove conteiner environment including volumes.
# [help_c] .t. Clean environment - containers, volumes (db storage), etc.
# [help_c] 
	clean-db)
                getDockerCompose | ${midPoint_env_exec} compose -f - down -v
                ;;
# [help_c] help .t..t. Show the help (this information)
# [help_c] 
	help)
		shift
		${midPoint_script} ${preserved_args} -h
		;;
	*)
		echo "Unknown command \"${1}\"."
		echo
		${midPoint_script} ${preserved_args} -h
                ;;
esac
