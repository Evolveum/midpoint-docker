#!/usr/bin/env bash

# global variables setup
midPoint_base_dir="$(pwd)"
midPoint_port=8080
midPoint_home_dir="midpoint-home"
midPoint_image_name="evolveum/midpoint"
midPoint_image_ver=4.9.3
midPoint_image_suffix="-alpine"
midPoint_uid=$(id -u)
midPoint_gid=$(id -g)
midPoint_initPw=""
midPoint_logo='
                   _ _____              _
             _    | |  _  \     _     _| |_
   ___ ____ (_) __| | |_) |___ (_)___|_   _|
  |  _ ` _ `| |/ _  |  __/  _ \| |  _` | |
  | | | | | | | (_| | |  | (_) | | | | | |_
  |_| |_| |_|_|\____|_|  \____/|_|_| |_|\__|  by Evolveum and partners

'

# helper functions - get_running_port, validate_password, get_password
get_running_port() {
    local port=$(docker ps \
    --filter "label=${midPoint_label}" \
    --filter "ancestor=${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}" \
    --format "{{.Ports}}" | grep -oE '[0-9]+->8080/tcp' | head -n1 | cut -d'-' -f1)

    echo "${port:-}"
}

# regex used to comply with midPoint to avoid clashes coming from midPoint
validate_password() {
  local tested_password=$1
  if [[ ${#tested_password} -lt 8 ]]; then
      echo "Your password needs to be at least 8 characters long."
      return 1
  elif ! [[ ${tested_password} =~ [A-Z] ]]; then
      echo "Your password needs to contain at least one uppercase letter."
      return 1
  elif ! [[ ${tested_password} =~ [a-z] ]]; then
      echo "Your password needs to contain at least one lowercase letter."
      return 1
  elif ! [[ ${tested_password} =~ [0-9] ]]; then
      echo "Your password needs to contain at least one number."
      return 1
  else
      return 0
  fi
}

# handles user kwarg password, interactive user password and midPoint generated password
get_password() {
    local requested_password=$1
    if [ -n "$requested_password" ]; then
      if validate_password "$requested_password"; then
          midPoint_initPw="$requested_password"
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
              midPoint_initPw=""
              break
          fi

          if validate_password "$pwd_input"; then
              midPoint_initPw="$pwd_input"
              break
          else
              echo "Please try again."
              echo ""
          fi
      done
    fi
}

# global setup functions - get_port, generate_instance_label used in global variables
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

        if [ "$requested_port" -lt 1024 ] || [ "$requested_port" -gt 65535 ]; then
            echo "Port must be between 1024 and 65535." >&2
            return 1
        fi

        if [ "$requested_port" == "$running_port" ]; then
            echo "$requested_port"
            return 0
        elif lsof -i :"$requested_port" >/dev/null 2>&1; then
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

generate_instance_label() {
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(echo -n "$midPoint_base_dir" | sha256sum | awk '{print $1}')
    else
        hash=$(echo -n "$midPoint_base_dir" | shasum -a 256 | awk '{print $1}')
    fi
    echo "MI${hash:0:32}"
}

midPoint_label="$(generate_instance_label)"

# gatekeeper section - checking the presence and content of the midpoint-home folder
if [ -d "$midPoint_home_dir" ]; then
    marker_file="$midPoint_home_dir/instance_marker"

    if [ ! -f "$marker_file" ] || ! source "$marker_file" || \
       [[ "$marker_midPoint_home_dir" != "$midPoint_home_dir" ]] || \
       [[ "$marker_midPoint_image_name" != "$midPoint_image_name" ]] || \
       [[ "$marker_midPoint_image_ver" != "$midPoint_image_ver" ]] || \
       [[ "$marker_midPoint_label" != "$midPoint_label" ]]; then
          cat <<EOF
WARNING: Existing midpoint-home does not match this instance and proceeding to run this script here may result in overwriting an existing midPoint instance.
Consider moving the script or using a different folder.
EOF
        read -r -p "Do you want to proceed in your current folder anyway? (Y/n) " choice
        if [[ "$choice" != "Y" ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
fi

# setup YAML function (not saved into any file)
get_docker_compose() {
cat <<EOF
services:
  midpoint_data:
    image: postgres:16-alpine
    labels:
      - ${midPoint_label}
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
    labels:
      - ${midPoint_label}
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
    labels:
      - ${midPoint_label}
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
      $( [ -n "$midPoint_initPw" ] && echo "- MP_SET_midpoint_administrator_initialPassword=${midPoint_initPw}" )
      - MP_UNSET_midpoint_repository_hibernateHbm2ddl=1
      - MP_NO_ENV_COMPAT=1
    networks:
      - net
    volumes:
      - ${midPoint_base_dir}/${midPoint_home_dir}:/opt/midpoint/var

networks:
  net:
    driver: bridge
    labels:
      - ${midPoint_label}

volumes:
  midpoint_data:
    labels:
      - ${midPoint_label}

EOF
}

# core functions - run_midpoint, show_info, show_logs, show_compose_file, show_help, delete_db, delete_midpoint, quit_midpoint
run_midpoint() {
  local requested_port=""
  local requested_password=""

  for arg in "$@"; do
    case $arg in
        port=*) requested_port="${arg#*=}" ;;
        password=*) requested_password="${arg#*=}" ;;
        *) echo "Unknown option $arg"; return 1 ;;
    esac
  done

  if [ -n "$requested_port" ]; then
      midPoint_port="$(get_port "$requested_port")" || return 1
  else
      midPoint_port="$(get_port)" || return 1
  fi

  if [ ! -d "$midPoint_home_dir" ]; then
      if [ -n "$requested_password" ]; then
          get_password "$requested_password" || return 1
      else
          get_password || return 1
      fi

      echo "Fresh installation  -  creating home folder and setting up MidPoint..."
      mkdir -p "$midPoint_home_dir"

      # creating marker file that is checked in the beginning of each run of this script
      cat <<EOF > "$midPoint_home_dir/instance_marker"
marker_midPoint_home_dir=$midPoint_home_dir
marker_midPoint_image_name=$midPoint_image_name
marker_midPoint_image_ver=$midPoint_image_ver
marker_midPoint_label=$midPoint_label
EOF

      if [ -z "$midPoint_initPw" ]; then
        unset MIDPOINT_ADMIN_PASSWORD
        echo "MidPoint will generate the administrator password automatically since none was defined by the user."
      else
        export MIDPOINT_ADMIN_PASSWORD="$midPoint_initPw"
      fi

      get_docker_compose | docker compose -f - up -d --wait --force-recreate --renew-anon-volumes
  else
      echo "Existing installation - restarting MidPoint..."
      if [ -n "$requested_password" ]; then
          echo "Password can be changed only in midPoint on existing installation. If you wish to set a new password here, you need to reset midPoint to factory settings."
      fi

      get_docker_compose | docker compose -f - up -d --force-recreate
  fi

  dockerExitCode=$?
  if [ "$dockerExitCode" -eq 0 ]; then
      echo
      echo "MidPoint has started..."
      echo "To access the WEB GUI go to: http://localhost:${midPoint_port}/midpoint/"
      echo "Username: administrator"
      if [ ! -d "$midPoint_home_dir" ] || [ -z "$midPoint_initPw" ]; then
        container_name=$(docker ps \
          --filter "label=${midPoint_label}" \
          --filter "ancestor=${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}" \
          --format "{{.Names}}" | head -n1)
        midPoint_initPw=$(docker logs "$container_name" 2>&1 \
          | grep "Administrator initial password" \
          | tail -n1 \
          | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -z "$midPoint_initPw" ]; then
          echo "Password set during first start of midPoint; if it was lost, reset midPoint to generate a new one."
        else
          echo "Initial automatically generated password: ${midPoint_initPw} (recommended to change in midPoint for increased security)"
        fi
      else
        echo "Initial password: ${midPoint_initPw} (recommended to change in MidPoint for increased security)"
      fi
  else
      echo "Something went wrong while starting MidPoint (exit code ${dockerExitCode})."
  fi
}

show_info() {
  local caller="${1:-gui}"

  echo "${midPoint_logo}"
  cat << EOF

Dual-licensed under Apache License 2.0 and European Union Public License.

Version: ${midPoint_image_ver}
Image:   ${midPoint_image_name}:${midPoint_image_ver}${midPoint_image_suffix}
EOF

if [[ "$caller" == "cli" ]]; then
  echo "Sources: https://github.com/Evolveum/midpoint"
fi

cat << EOF
Bug reporting system: https://support.evolveum.com/
Product information: https://midpoint.evolveum.com
Documentation: https://docs.evolveum.com/midpoint/quickstart/

EOF

  running_port="$(get_running_port)"
    

  if [ -n "$running_port" ]; then
      midPoint_port="$running_port"
  fi

  if [ -d "$midPoint_home_dir" ]; then
        cat << EOF
Home folder:   ${midPoint_base_dir}/${midPoint_home_dir}
Import folder: ${midPoint_base_dir}/${midPoint_home_dir}/import
Logs folder:   ${midPoint_base_dir}/${midPoint_home_dir}/logs

Web GUI: http://localhost:${midPoint_port}/midpoint/
Username: administrator
Password set during first start of midPoint; if it was lost, reset midPoint to generate a new one.

EOF
    else
        cat << EOF

MidPoint is not installed yet — use run to generate home folder and default password.

Script name: $(basename "$0")
Running in folder: ${midPoint_base_dir}

EOF
    fi
}

show_logs() {
    container_name=$(docker ps \
        --filter "label=${midPoint_label}" \
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
              port        Select port number (1024 - 65535) on which midPoint will run;
              password    set initial password for midPoint (works only on initial start, otherwise is ignored)
  info      Show version, image, and environment details
  yaml      Print the Docker Compose YAML used internally by this script; the file is not saved in the enironment
  logs      Display logs of the running midPoint container; press 'b' to stop the logs
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

        docker ps -a --filter "label=${midPoint_label}" --format "{{.Names}}" | xargs -r docker rm -f
        docker network ls --filter "label=${midPoint_label}" --format "{{.Name}}" | xargs -r docker network rm
        docker volume ls --filter "label=${midPoint_label}" --format "{{.Name}}" | xargs -r docker volume rm
        rm -rf "$midPoint_home_dir"
        echo "Database has been reset."

        if [ -n "$running_port" ]; then
          echo "MidPoint will now restart automatically."
          run_midpoint port="$running_port"
        else
          echo "MidPoint can now be started again."
        fi
    else
        echo "No database to reset yet, start midPoint first."
    fi
}

delete_midpoint() {
    echo "Removing current midPoint version"

    docker ps -a --filter "label=${midPoint_label}" --format "{{.Names}}" | xargs -r docker rm -f
    docker network ls --filter "label=${midPoint_label}" --format "{{.Name}}" | xargs -r docker network rm
    docker volume ls --filter "label=${midPoint_label}" --format "{{.Name}}" | xargs -r docker volume rm

    # handles error messages coming from docker image use overlapping by other midPoint instances
    local image_errors
    image_errors=$(docker images --filter "label=${midPoint_label}" --format "{{.Repository}}:{{.Tag}}" | xargs -r docker rmi -f 2>&1)
    echo "$image_errors"
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

    # handles the case of "busy port" lagging after deleting 
    running_port="$(get_running_port)"
    local timeout=3
    local interval=1
    local elapsed=0
    local force_freed=false

    while lsof -i :"$running_port" -sTCP:LISTEN -t -u "$USER" >/dev/null 2>&1; do
        if (( elapsed >= timeout )); then
            echo "Freeing port ${running_port}..."
            force_freed=true
            lsof -ti :"$running_port" -sTCP:LISTEN -u "$USER" | xargs -r kill -9
            break
        fi
        sleep $interval
        ((elapsed += interval))
    done

    if [ "$force_freed" = true ]; then
        echo "Port ${running_port} is now free."
    fi
}

quit_midpoint() {
    echo "Shutting down midPoint..."
    get_docker_compose | docker compose -f - stop
    echo "Shut down complete."
    exit 0
}

# wrapper function for user confirmation of delete_db and delete_midpoint - only used in default mode with GUI menu
get_user_choice() {
    local prompt="$1"
    local choice

    read -r -p "$prompt (Y/n) " choice

    if [[ "$choice" == "Y" ]]; then
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

delete_midpoint_after_confirm() {
    local warning_message
    warning_message=$(cat <<EOF
This action will permanently delete the whole current midPoint application, including all its data, settings and program files.
Other midPoint instances on this computer will keep their data safe but they may take longer to start next time they are used.
Are you sure you want to proceed?
EOF
)

    if ! get_user_choice "$warning_message"; then
        return
    fi

    delete_midpoint
}

# interface section
# basic GUI menu function
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
        read -r -p "Select option: " CHOICE_RAW
        CHOICE=$(echo "$CHOICE_RAW" | tr '[:upper:]' '[:lower:]')

        case $CHOICE in
            s) run_midpoint ;;
            i) show_info ;;
            l) show_logs ;;
            res) delete_db_after_confirm ;;
            del) delete_midpoint_after_confirm ;;
            q) quit_midpoint ;;
            *) echo "Unknown choice, please try again." ;;
        esac
    done
}

# advanced control args and default GUI menu function call for no arg case
cmd="$1"
shift || true

requested_port=""
requested_password=""

for arg in "$@"; do
    case $arg in
        port=*)
            requested_port="${arg#*=}"
            ;;
        password=*)
            requested_password="${arg#*=}"
            ;;
          *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

case "$cmd" in
    start)
        run_midpoint "port=$requested_port" "password=$requested_password"
        exit 0
        ;;
    info)
        show_info cli
        exit 0
        ;;
    help)
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
        delete_midpoint
        exit 0
        ;;
    stop)
        quit_midpoint
        exit 0
        ;;
      "")
        show_default_menu
        ;;
    *)
        echo "Invalid option"
        exit 0
        ;;
esac
