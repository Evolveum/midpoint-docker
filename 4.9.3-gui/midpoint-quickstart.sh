#!/usr/bin/env bash

##########################
# global variables setup #
##########################
midPoint_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
midPoint_instance_marker="instance_marker"
midPoint_port=8080
midPoint_home_dir="midpoint-home"
midPoint_image_name="evolveum/midpoint"
midPoint_image_ver=4.9.3
midPoint_image_suffix="-alpine"
midPoint_uid=$(id -u)
midPoint_gid=$(id -g)
midPoint_init_pwd=""
midPoint_logo='
                   _ _____              _
             _    | |  _  \     _     _| |_
   ___ ____ (_) __| | |_) |___ (_)___|_   _|
  |  _ ` _ `| |/ _  |  __/  _ \| |  _` | |
  | | | | | | | (_| | |  | (_) | | | | | |_
  |_| |_| |_|_|\____|_|  \____/|_|_| |_|\__|  by Evolveum and partners

'

######################################################################################
# gatekeeper section - checking the presence and content of the midpoint-home folder #
######################################################################################
if [ -d "$midPoint_home_dir" ]; then
    marker_file="$midPoint_home_dir/$midPoint_instance_marker"

    if [ ! -f "$marker_file" ] || ! source "$marker_file" || \
       [[ "$marker_midPoint_home_dir" != "$midPoint_home_dir" ]] || \
       [[ "$marker_midPoint_image_name" != "$midPoint_image_name" ]] || \
       [[ "$marker_midPoint_image_ver" != "$midPoint_image_ver" ]]; then
          cat <<EOF
WARNING: Existing midpoint-home does not match this instance and proceeding to run this script here may result in overwriting an existing midPoint instance.
Consider moving the script or using a different folder.
EOF
        read -r -p "Do you want to proceed in your current folder anyway? (y/N) " choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [[ "$choice" == "y" ]]; then
            echo "This script will overwrite the data of the previous midPoint instance that ran from this folder."
            rm -rf "$midPoint_home_dir"
        else
            echo "Aborted."
            exit 1
        fi
    fi
fi

##############################################################
# helper functions - get_running_port, validate_pwd, get_pwd #
##############################################################
get_running_port() {
    local port=$(docker ps \
    --filter "name=^${midPoint_instance_name}" \
    --filter "ancestor=${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}" \
    --format "{{.Ports}}" | grep -oE '[0-9]+->8080/tcp' | head -n1 | cut -d'-' -f1)

    echo "${port:-}"
}

validate_pwd() {
  local tested_pwd=$1

  # regex used to comply with midPoint to avoid clashes coming from midPoint
  if [[ ${#tested_pwd} -lt 8 ]]; then
      echo "Your password needs to be at least 8 characters long."
      return 1
  elif ! [[ ${tested_pwd} =~ [A-Z] ]]; then
      echo "Your password needs to contain at least one uppercase letter."
      return 1
  elif ! [[ ${tested_pwd} =~ [a-z] ]]; then
      echo "Your password needs to contain at least one lowercase letter."
      return 1
  elif ! [[ ${tested_pwd} =~ [0-9] ]]; then
      echo "Your password needs to contain at least one number."
      return 1
  else
      return 0
  fi
}

# handles user kwarg password, interactive user password and midPoint generated password
get_pwd() {
    local requested_pwd=$1
    if [ -n "$requested_pwd" ]; then
      if validate_pwd "$requested_pwd"; then
          midPoint_init_pwd="$requested_pwd"
          return 0
      else
          return 1
      fi
    else
      while true; do
        cat << EOF
Enter your new admin password.
The password must:
 - be at least 8 characters long,
 - contain one number,
 - contain one upper case,
 - contain one lower case letter
For automatically generated password in midPoint, leave blank and press ENTER.

EOF
          read -r -p "" pwd_input
          if [ -z "$pwd_input" ]; then
              midPoint_init_pwd=""
              break
          fi

          if validate_pwd "$pwd_input"; then
              midPoint_init_pwd="$pwd_input"
              break
          else
              echo "Please try again."
              echo ""
          fi
      done
    fi
}

##################################################################################
# global setup functions -  get_instance_name, get_port used in global variables #
##################################################################################
get_instance_name() {
    local requested_instance_name=$1
    local marker_file="${midPoint_home_dir}/${midPoint_instance_marker}"
    local existing_containers=($(docker ps --format "{{.Names}}"))

    if [ -f "$marker_file" ]; then
      source "$marker_file"
      echo "$marker_midPoint_instance_name"
      return 0
    fi

    if [ -n "$requested_instance_name" ]; then
        if [[ "$requested_instance_name" =~ ^[a-z0-9][a-z0-9_-]{0,249}$ ]]; then
            if printf '%s\n' "${existing_containers[@]}" | grep -q "^${requested_instance_name}-"; then
                echo "Instance name '$requested_instance_name' already exists as a Docker container." >&2
                return 1
            fi
            echo "$requested_instance_name"
        else
            if [[ ! "$requested_instance_name" =~ ^[a-z0-9] ]]; then
                echo "The first character of instance name must be a lowercase letter or a number." >&2
            elif [[ "$requested_instance_name" =~ [A-Z] ]]; then
                echo "The instance name cannot use uppercase letters." >&2
            elif [[ "$requested_instance_name" =~ [^a-z0-9_-] ]]; then
                echo "The instance name can only use lowercase letters, numbers, hyphen, or underscore; no spaces or other characters are allowed." >&2
            fi
            return 1
        fi
    else
        while true; do
            random_hash="$(dd if=/dev/urandom bs=64 count=4 2>/dev/null | base64 | tr -d '/=+' | tr '[:upper:]' '[:lower:]' | tr -dc 'a-z0-9' | cut -c1-6)"
            random_instance_name="midpoint-quickstart-${random_hash}"
            if ! printf '%s\n' "${existing_containers[@]}" | grep -q "^${random_instance_name}-"; then
                echo "$random_instance_name"
                break
            fi
        done
    fi
}

midPoint_instance_name="$(get_instance_name)"

get_port() {
    local requested_port="$1"
    local default_start=8080
    local max_port=9000

    if [ -z "$requested_port" ]; then
        running_port="$(get_running_port)" || return 1
    fi

    if [ -n "$requested_port" ]; then
        if ! [[ "$requested_port" =~ ^[0-9]+$ ]]; then
            echo "Port must be a positive integer." >&2
            return 1
        fi

        if [ "${#requested_port}" -gt 5 ]; then
          echo "Port too large, must be lower than 65535." >&2
          return 1
        fi

        if [ "$requested_port" -lt 1 ] || [ "$requested_port" -gt 65535 ]; then
            echo "Port must be between 1 and 65535." >&2
            return 1
        fi

        if [ "$requested_port" == "$running_port" ]; then
            echo "$requested_port"
            return 0
        # checking for the running port here is different to prevent false busy detection in TIME_WAIT/CLOSE_WAIT
        elif lsof -iTCP:"$requested_port" -sTCP:LISTEN >/dev/null 2>&1; then
            echo "Port $requested_port is busy, choose a different one" >&2
            return 1
        else
            echo "$requested_port"
            return 0
        fi
    fi

    if [ -n "$running_port" ]; then
        echo "$running_port"
        return 0
    fi

    local port="$default_start"
    while [ "$port" -le "$max_port" ]; do
        if lsof -i :"$port" >/dev/null 2>&1; then
            port=$((port + 1))
        else
            echo "$port"
            return 0
        fi
    done

    echo "No available port found between $default_start and $max_port" >&2
    return 1
}

# setup YAML function (not saved into any file)
get_docker_compose() {
cat <<EOF
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
      ) || echo -e '\\n Repository init is not needed...' ;
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
      $( [ -n "$midPoint_init_pwd" ] && echo "- MP_SET_midpoint_administrator_initialPassword=${midPoint_init_pwd}" )
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

################################################################################################################################
# core functions - run_midPoint, show_info, show_logs, show_compose_file, show_help, delete_db, delete_midPoint, quit_midPoint #
################################################################################################################################
run_midPoint() {
  local requested_port=""
  local requested_pwd=""
  local requested_instance_name=""

  for arg in "$@"; do
    case $arg in
        port=*) requested_port="${arg#*=}" ;;
        password=*) requested_pwd="${arg#*=}" ;;
        name=*) requested_instance_name="${arg#*=}" ;;
        *) echo "Unknown option $arg"; return 1 ;;
    esac
  done

  midPoint_port="$(get_port "$requested_port")" || return 1

  if [ ! -d "$midPoint_home_dir" ]; then
      midPoint_instance_name="$(get_instance_name "$requested_instance_name")" || return 1
      
      get_pwd "$requested_pwd" || return 1

      echo "Fresh installation  -  creating home folder and setting up midPoint..."
      mkdir -p "$midPoint_home_dir" || { echo "ERROR: Failed to create $midPoint_home_dir" >&2; return 1; }

      # creating marker file that is checked in the beginning of each run of this script
      cat <<EOF > "$midPoint_home_dir/$midPoint_instance_marker" || { echo "ERROR: Failed to create instance_marker file" >&2; return 1; }
marker_midPoint_home_dir=$midPoint_home_dir
marker_midPoint_image_name=$midPoint_image_name
marker_midPoint_image_ver=$midPoint_image_ver
marker_midPoint_instance_name=$midPoint_instance_name
EOF

      if [ -z "$midPoint_init_pwd" ]; then
        unset MIDPOINT_ADMIN_PASSWORD
        echo "Administrator password will be generated automatically by midPoint since none was defined by the user."
      else
        export MIDPOINT_ADMIN_PASSWORD="$midPoint_init_pwd"
      fi

      get_docker_compose | docker compose -p "$midPoint_instance_name" -f - up -d --wait --force-recreate --renew-anon-volumes || { echo "ERROR: Failed to start containers." >&2; return 1; }
  else
      echo "Existing installation - restarting midPoint..."
      if [ -n "$requested_pwd" ]; then
          echo "Password can be changed only in midPoint on existing installation. You can change it in midPoint in your Profile settings. If you wish to set a new password here, you need to reset midPoint to factory settings."
      fi

      if [ -n "$requested_instance_name" ]; then
          echo "Name of the project cannot be changed on existing installation. If you wish to change it, you need to delete this instance and start a new one."
      fi

      get_docker_compose | docker compose -p "$midPoint_instance_name" -f - up -d --force-recreate || { echo "ERROR: Failed to restart containers." >&2; return 1; }
  fi

  echo
  echo "Starting midPoint..."
  echo "To access the WEB GUI go to: http://localhost:${midPoint_port}/midpoint/"
  echo "Username: administrator"

  if [ ! -d "$midPoint_home_dir" ] || [ -z "$midPoint_init_pwd" ]; then
    container_name=$(docker ps \
      --filter "name=^${midPoint_instance_name}" \
      --filter "ancestor=${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}" \
      --format "{{.Names}}" | head -n1)

    if [ -z "$container_name" ]; then
      echo "Could not determine container name." >&2
      return 1
    fi

    midPoint_init_pwd=$(docker logs "$container_name" 2>&1 \
      | grep "Administrator initial password" \
      | tail -n1 \
      | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$midPoint_init_pwd" ]; then
      echo "Password set during first start of midPoint; if it was lost, reset midPoint to generate a new one."
    else
      echo "Initial automatically generated password: ${midPoint_init_pwd} (recommended to change in midPoint for increased security)"
    fi
  else
    echo "Initial password: ${midPoint_init_pwd} (recommended to change in midPoint for increased security)"
  fi
}

show_info() {
  local caller="${1:-gui}"

  echo "${midPoint_logo}"
  cat << EOF

Dual-licensed under Apache License 2.0 and European Union Public License.

Version:                        ${midPoint_image_ver}
Image:                          ${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}
EOF

if [[ "$caller" == "cli" ]]; then
  echo "Sources:                        https://github.com/Evolveum/midpoint"
fi

cat << EOF
Bug reporting system:           https://support.evolveum.com/
Product information:            https://midpoint.evolveum.com
Documentation:                  https://docs.evolveum.com/midpoint/quickstart/

EOF

  running_port="$(get_running_port)"
    

  if [ -n "$running_port" ]; then
      midPoint_port="$running_port"
  fi

  if [ -d "$midPoint_home_dir" ]; then
        cat << EOF
Home folder:                    ${midPoint_base_dir}/${midPoint_home_dir}/
Import folder:                  ${midPoint_base_dir}/${midPoint_home_dir}/import/
Logs folder:                    ${midPoint_base_dir}/${midPoint_home_dir}/logs/

Import path in midPoint:        /opt/midpoint/var/import/

Instance name:                  ${midPoint_instance_name}
Server container:               ${midPoint_instance_name}-midpoint_server-1
Database container:             ${midPoint_instance_name}-midpoint_data-1

Web GUI:                        http://localhost:${midPoint_port}/midpoint/
Username:                       administrator
Password set during first start of midPoint; if it was lost, reset midPoint to generate a new one.

EOF
    else
        cat << EOF

midPoint is not installed yet — use run to generate home folder and default password.

Script name: $(basename "$0")
Running in folder: ${midPoint_base_dir}

EOF
    fi
}

show_logs() {
    container_name=$(docker ps \
        --filter "name=^${midPoint_instance_name}" \
        --filter "ancestor=${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}" \
        --format "{{.Names}}" | head -n1)

    if [ -z "$container_name" ]; then
        echo "No running midpoint_server container found."
        echo "Start midPoint first."
        return
    fi

    echo "Showing logs for container: $container_name"
    echo "Press 'b' then ENTER to stop following logs..."

    docker logs -f --tail 50 "$container_name" &
    logs_pid=$!

    while true; do
        read -r -n1 key
        key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        if [[ $key == "b" ]]; then
            kill "$logs_pid" 2>/dev/null
            wait "$logs_pid" 2>/dev/null
            echo -e "\nStopped log follow."
            break
        fi
    done
}

show_compose_file() {
  running_port="$(get_running_port)"
    if [ -n "$running_port" ]; then
        midPoint_port="$running_port"
    fi

    get_docker_compose
}

show_help() {
    cat << EOF
This scripts uses Docker images and simplifies their running without presuming any previous experience with Docker on the user side. Using this script, it is possible to run midPoint locally on user's localhost.

Usage: $(basename "$0") [OPTION]

Option:
  start     Start midPoint using Docker Compose; takes 2 optional keyword arguments:
              --port (-p)       Select port number (up to 65535) on which midPoint will run;
              --password (-w)   Set initial password for midPoint (works only on initial start, otherwise is ignored)
              --name (-n)       Set name of the project for docker containers, volumes and network (works only on initial start, otherwise is ignored)
  info      Show version, image, and environment details
  yaml      Print the Docker Compose YAML used internally by this script; the file is not saved in the environment
  logs      Display logs of the running midPoint container; press 'B' to stop the logs
  stop      Stop midPoint without deleting user's data
  reset     Reset midPoint to factory settings; delete database (including password)
  delete    Delete midPoint (containers, volumes, images, and local data, including password)
  help      Display this help message

Option 'start' may take a few minutes on the first run. It needs to be used before accessing midPoint on localhost. It needs to be used after 'down', 'delete' or quitting the interactive menu.

If no option is provided, an interactive menu will be shown by default.

EOF
}

delete_db() {
    if [ -d "$midPoint_home_dir" ]; then
        running_port="$(get_running_port)"

        get_docker_compose | docker compose -p "$midPoint_instance_name" -f - down --volumes

        rm -rf "$midPoint_home_dir"
        echo "Database has been reset."

        if [ -n "$running_port" ]; then
          echo "midPoint will now restart automatically."
          run_midPoint port="$running_port" name="$midPoint_instance_name"
        else
          echo "midPoint can now be started again."
        fi
    else
        echo "No database to reset yet, start midPoint first."
    fi
}

delete_midPoint() {
    echo "Removing current midPoint version"

    get_docker_compose | docker compose -p "$midPoint_instance_name" -f - down --volumes

    # handles error messages coming from docker image use overlapping by other midPoint instances without error messages explaining why some images cannot be removed
    local image_errors
    image_errors+=$(docker images "${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}" -q | xargs -r docker rmi -f 2>&1)
    image_errors+=$(docker images "postgres:16-alpine" -q | xargs -r docker rmi -f 2>&1)

    if [ -d "$midPoint_home_dir" ]; then
        rm -rf "$midPoint_home_dir"
    fi

    if [[ "$image_errors" == *"cannot be forced"* ]]; then
        echo "Note: Some program files could not be deleted because they are still being used by other midPoint instances running on this computer."
        echo "This instance of midPoint has been successfully deleted."
    else
        echo "All midPoint program files and local data installed by this script have been successfully deleted."
    fi
}

quit_midPoint() {
    echo "Shutting down midPoint..."
    get_docker_compose | docker compose -p "$midPoint_instance_name" -f - down
    echo "Shut down complete."
    exit 0
}

# wrapper function for user confirmation of delete_db and delete_midPoint - only used in default mode with GUI menu
get_user_choice() {
    local prompt="$1"
    local choice

    read -r -p "$prompt (y/N) " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    if [[ "$choice" == "y" ]]; then
      return 0
    else
      echo "Aborted"
      return 1
    fi
}

# after_confirm functions wrap delete_midpoint and delete_db; for calling from the GUI menu only
delete_db_after_confirm() {
  if ! get_user_choice "This action will delete all the data and cannot be undone. Are you sure you want to proceed?"; then      
    return
  fi

  delete_db
}

delete_midPoint_after_confirm() {
    local warning_message
    warning_message=$(cat <<EOF
This action will permanently delete the current midPoint instance, including all its data, settings, and files. Other instances that may have been running on this computer will remain safe. Are you sure you want to proceed?
EOF
)

    if ! get_user_choice "$warning_message"; then
        return
    fi

    delete_midPoint
}
#####################
# interface section #
#####################
# default GUI menu function
show_default_menu() {
    echo "${midPoint_logo}"
    while true; do
    cat << EOF
+------------------------------+
|        -- MAIN MENU --       |
|------------------------------|
| (S)tart midPoint             |
| (I)nformation                |
| (L)ogs, then (b)ack          |
+------------------------------+
| (RES)et to factory settings  |
| (DEL)ete midPoint            |
+------------------------------+
| (Q)uit and stop midPoint     |
+------------------------------+
EOF
        read -r -p "Select option: " choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        case $choice in
            s) run_midPoint ;;
            i) show_info ;;
            l) show_logs ;;
            res) delete_db_after_confirm ;;
            del) delete_midPoint_after_confirm ;;
            q) quit_midPoint ;;
            *) echo "Unknown choice, please try again." ;;
        esac
    done
}

# advanced control args and default GUI menu function call for no arg case
cmd="$1"
requested_port=""
requested_pwd=""
requested_instance_name=""

# proprietary parsing used instead of getopt to ensure consistent working in MacOS default bash BSD version
while [ $# -gt 0 ]; do
    case "$1" in
        --port|-p)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: --port requires a value, e.g. --port 8080"
                exit 1
            fi
            requested_port="$2"
            shift 2
            ;;
        --password|-w)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: --password requires a value, e.g. --password 5ecretPassw0rd"
                exit 1
            fi
            requested_pwd="$2"
            shift 2
            ;;
        --name|-n)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: --name requires a value, e.g. --name midpoint-instance"
                exit 1
            fi
            requested_instance_name="$2"
            shift 2
            ;;
        start|info|logs|yaml|reset|delete|stop|help|--help|-h)
            cmd="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Type --help to display basic commands."
            exit 1
            ;;
    esac
done

case "$cmd" in
    start)
        run_midPoint "port=$requested_port" "password=$requested_pwd" "name=$requested_instance_name"
        exit 0
        ;;
    info)
        show_info cli
        exit 0
        ;;
    help|--help|-h)
        show_help
        exit 0
        ;;
    logs)
        show_logs
        exit 0
        ;;
    yaml)
        show_compose_file
        exit 0
        ;;
    reset)
        delete_db
        exit 0
        ;;
    delete)
        delete_midPoint
        exit 0
        ;;
    stop)
        quit_midPoint
        exit 0
        ;;
      "")
        show_default_menu
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
