#!/bin/bash

NAME="${NAME:-dev-server}"
IMAGE="${IMAGE:-ubuntu-20-04-x64}"
SPECS="${SPECS:-s-2vcpu-2gb}"
REGION="${REGION:-lon1}"
CLOUD_CONFIG="${CLOUD_CONFIG:-./dev-server/cloud-config.yml}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/developer}"
SSH_PUBKEY="${SSH_PUBKEY:-$HOME/.ssh/developer.pub}"
SSH_USER="${SSH_USER:-developer}"
SSH_HOST="${SSH_HOST:-}" # configured at runtime, see ssh_host() function
SSH_SOCKET="${SSH_SOCKET:-}" # configured at runtime, see ssh_socket() function
SSH_CWD="${SSH_CWD:-}" # configured on-demand when running ssh_cwd() function
LOCAL_CWD="${LOCAL_CWD:-$(pwd)}"
SSH_HOST_FILE="${SSH_HOST_FILE:-/tmp/dev_ssh_host}"
SSH_CWD_FILE="${SSH_CWD_FILE:-/tmp/dev_ssh_cwd}"

red() {
    echo -e "\033[0;31m$*\033[0m"
}

yellow() {
    echo -e "\033[0;33m$*\033[0m"
}

green() {
    echo -e "\033[0;32m$*\033[0m"
}

echo_config_name() {
    name=$(basename "${CLOUD_CONFIG%.*}")
    ext=$(basename "${CLOUD_CONFIG##*.}")
    config="/tmp/$name.generated.$ext"
    echo "$config"
}

generate_config() {
    echo "Generating config…"
    echo ""

    config=$(echo_config_name)

    if [[ ! -e "$CLOUD_CONFIG" ]]; then
        echo ""
        red "Config $CLOUD_CONFIG does not exist!"
        red "It is required to generate config!"
        exit 66
    fi

    sed -e "s#{ssh-pubkey}#$(cat "$SSH_PUBKEY")#g" \
        "$CLOUD_CONFIG" > "$config"
}

delete_droplets_unsafe() {
    droplets=$(doctl compute droplet list --no-header)

    if echo "$droplets" | grep -iq error; then
        echo ""
        red "Failed to delete droplets due to error:"
        red "$droplets"
        exit 70
    fi

    if [[ -z "$droplets" ]]; then
        echo ""
        echo "No droplet instance(s) to delete…"
        echo ""
        return
    fi
    echo ""
    echo "Deleting previous instance(s)…"
    echo ""
    echo "$droplets" | grep -w "$NAME" | tr -s ' ' \
    | cut -d ' ' -f 1 | xargs doctl compute droplet delete --force
}

delete_tmp_ssh_host() {
    if [[ ! -e "$SSH_HOST_FILE" ]]; then
        echo "No tmp file to delete ($SSH_HOST_FILE)…"
        echo ""
        return
    fi
    echo "Deleting tmp file ($SSH_HOST_FILE)…"
    echo ""
    rm "$SSH_HOST_FILE"
}

delete_tmp_cwd_host() {
    if [[ ! -e "$SSH_CWD_FILE" ]]; then
        echo "No tmp file to delete ($SSH_CWD_FILE)…"
        echo ""
        return
    fi
    echo "Deleting tmp file ($SSH_CWD_FILE)…"
    echo ""
    rm "$SSH_CWD_FILE"
}

delete_tmp_cloud_config() {
    config=$(echo_config_name)

    if [[ ! -e "$config" ]]; then
        echo "No tmp file to delete ($config)"
        echo ""
        return
    fi

    echo "Deleting tmp file ($config)…"
    echo ""
    rm "$config"
}

delete_tmp() {
    delete_tmp_ssh_host
    delete_tmp_cwd_host
    delete_tmp_cloud_config
}

echo_specs() {
    echo "Name:         $NAME"
    echo "Image:        $IMAGE"
    echo "Size:         $SPECS"
    echo "Region:       $REGION"
    echo ""
}

delete_droplets_safe() {
    count=$(doctl compute droplet list --no-header \
    | grep -w "$NAME" | tr -s ' ' | cut -d ' ' -f 1 | wc -l | xargs)

    if echo "$count" | grep -iq error; then
        red "Failed to count droplets due to error: $count!"
        exit 66
    fi

    if [[ "$count" -gt 0 ]]; then
        yellow "Found $count instance(s) of droplet $NAME"
        while [[ "$delete" = "${delete#[YyNn]}" ]]; do
            echo ""
            read -r -p $'\033[0;33mDelete? [Yy/Nn]\033[0m ' -n 1 delete
            echo ""
        done
        case $delete in
            [Yy])
                delete_droplets_unsafe
                ;;
            [Nn])
                echo ""
                yellow "This script follows a singleton pattern, implying"
                yellow "it supports only 1 active droplet at any given time"
                echo ""
                yellow "To proceed forward, you are required to delete active"
                yellow "droplet instance; you may do so by re-running this"
                yellow "command 'do.sh $*' and replying 'y' to this question"
                # non an error since user intended action;
                # need to stop code because user wishes so
                exit 0
                ;;
        esac
    else
        echo "No droplets to delete…"
        echo ""
    fi
}

create_droplet() {
    echo "Creating droplet…"
    echo ""

    if ! [[ -e "$CLOUD_CONFIG" ]]; then
        red "Cloud config '$CLOUD_CONFIG' does not exist!"
        exit 66
    fi

    config=$(echo_config_name)

    SSH_HOST=$(doctl compute droplet create "$NAME" \
      --image "$IMAGE" \
      --size "$SPECS" \
      --region "$REGION" \
      --user-data-file="$config" \
      --format PublicIPv4 \
      --no-header \
      --wait)

    if ! echo "$SSH_HOST" | grep -iq error; then
        green "$SSH_HOST"
        echo ""
        echo "$SSH_HOST" > "$SSH_HOST_FILE"
    else
        red "Failed to create droplet: $NAME"
        red "Received the following error:"
        red "$SSH_HOST"
        exit 70
    fi

    echo "Waiting 30 seconds for droplet to boot…"
    echo ""
    # avoid connecting too early otherwise will run into various issues
    # such as no ssh connectivity or unresponsive host
    sleep 30
}

ssh_agent() {
    echo "Starting ssh-agent…"
    echo ""
    eval ssh-agent
    echo ""

    echo "Adding ssh-key to ssh-agent…"
    ssh-add "$SSH_KEY"
    echo ""

    echo "Caching ssh-key passphrase…"
    # need to send anything to remote to cache ssh-key passphrase
    # echo " " produces no output so it is suitable choice
    ssh_cmd echo " "
}

droplet_ready() {
    while :; do
        raw_status=$(ssh_cmd cloud-init status)
        status=$(echo "$raw_status" | tr -s ' ' | cut -d ' ' -f 2 | xargs)
        case $status in
            running)
                echo "cloud-init is still running…"
                echo ""
                # 10 seconds seems like a good balance between waiting for too
                # long i.e. host is ready but the script is still 'sleeping' or
                # checking too frequently leading to too many messages to user
                sleep 10
                ;;
            error)
                config=$(echo_config_name)
                red "Failed to configure droplet using cloud-init config:"
                red "$config"
                red "Cloud-init configuration failed with status:"
                red "$(ssh_cmd cloud-init status -l)"
                exit 70
                ;;
            done)
                green "$(ssh_cmd tail -n 1 /var/log/cloud-init-output.log)"
                break;
        esac
    done
}

sync() {
    if ! [[ -e "$SSH_HOST_FILE" ]]; then
        red "No tmp file ($SSH_HOST_FILE)…"
        exit 70
    fi

    ssh_socket

    if [[ ! -e "${HOME}/.ssh/sockets/" ]]; then
        # .ssh dir should exist as without it ssh connection not possible
        # (implying that OpenSSH is not configured)
        mkdir "${HOME}/.ssh/sockets/"
    fi

    rsync -az --progress --delete \
        --exclude=/\.git \
        --exclude=/node_modules \
        --exclude=/dist \
        -e "ssh -i $SSH_KEY \
            -o \"ControlMaster=auto\" \
            -o \"ControlPath=$SSH_SOCKET\" \
            -o \"ControlPersist=600\" \
        " \
    ./ "$SSH_USER@$SSH_HOST":~/repo
}

watch() {
    fswatch -xLr0 --event-flag-separator=', ' ./ \
        -e "/\.git" \
        -e "/node_modules" \
        -e "/dist" \
    | while read -rd "" file event
    do
        echo ""
        echo "File: ${file#$(pwd)/}"
        echo "Event: $event"
        echo "Rsync: running…"
        sync # sync() function call
        echo ""
    done
}

ssh_host() {
    if [[ -z "$SSH_HOST" && ! -e "$SSH_HOST_FILE" ]]; then
        red "Unable to get SSH host IP address!"
        # echo literal, not value of variable
        # shellcheck disable=SC2016
        red 'Env var $SSH_HOST is empty!'
        red "Tmp file ($SSH_HOST_FILE) is missing!"
        red "Either remote is not running or could not write $SSH_HOST_FILE!"
        exit 66
    else
        SSH_HOST=$(cat "$SSH_HOST_FILE")
    fi
}

ssh_socket() {
    ssh_host
    SSH_SOCKET="${HOME}/.ssh/sockets/$SSH_USER@$SSH_HOST"
}

ssh_close() {
    # https://unix.stackexchange.com/a/459476
    ssh_socket
    if [[ -S "$SSH_SOCKET" ]]; then
        ssh -o ControlPath="$SSH_SOCKET" -O stop bogus
        echo ""
    fi
}

ssh_cwd() {
    if [[ -z "$SSH_CWD" && ! -e "$SSH_CWD_FILE" ]]; then
        SSH_CWD=$(ssh_cmd pwd)
        echo "$SSH_CWD" > "$SSH_CWD_FILE"
    else
        SSH_CWD=$(cat "$SSH_CWD_FILE")
    fi
}

ssh_cmd() {
    ssh_socket
    ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" \
        -o "ControlMaster=auto" \
        -o "ControlPath=$SSH_SOCKET" \
        -o "ControlPersist=600" \
    "$@"
}

deps() {
    ssh_cmd -t "yarn install"
}

up() {
    echo_specs
    delete_droplets_safe
    generate_config
    create_droplet
    ssh_agent
    droplet_ready
}

down() {
    delete_droplets_safe
    # sub-shell is required to continue running if ssh_host returns exit code 1
    if (ssh_host > /dev/null); then
        ssh_close
    fi
    delete_tmp
}

copy_host() {
    ssh_host
    if [[ -n $(command -v pbcopy) ]]; then
        echo "$SSH_HOST     (copied via pbcopy)"
        echo -e "$SSH_HOST\c" | pbcopy
    else
        echo "$SSH_HOST"
    fi
}

copy_from_local() {
    # $arg = current argument (string)
    # $next_args = next arguments excluding current (array)
    # see for…in loop at the bottom for details

    ssh_host
    ssh_socket

    # ${#paramter} -> get array length
    # $next_args[*] -> get array as string separated by $IFS
    files_count="${#next_args[*]}"

    # copying only 1 file
    if [[ "$files_count" -eq 1 ]]; then
        file="${next_args[*]}"
        scp -i "$SSH_KEY" \
            -o ControlMaster=auto \
            -o ControlPath="$SSH_SOCKET" \
            -o ControlPersist=600 \
        -r "$file" "$SSH_USER@$SSH_HOST:./"
    fi

    # copying multiple (1+) files
    if [[ "$files_count" -gt 1 ]]; then
        # https://stackoverflow.com/a/21691584/4343719
        scp -i "$SSH_KEY" \
            -o ControlMaster=auto \
            -o ControlPath="$SSH_SOCKET" \
            -o ControlPersist=600 \
        -r "${next_args[@]}" "$SSH_USER@$SSH_HOST:./"
    fi
}

copy_from_remote() {
    # $arg = current argument (string)
    # $next_args = next arguments excluding current (array)
    # see for…in loop at the bottom for details

    # if calling 'do.sh dist', copy dist/ from remote
    if [[ "$arg" = 'dist' ]]; then
        next_args=('dist/')
    fi

    ssh_host
    ssh_socket

    # ${#paramter} -> get array length
    # $next_args[*] -> get array as string separated by $IFS
    files_count="${#next_args[*]}"

    # copying only 1 file
    if [[ "$files_count" -eq 1 ]]; then
        file="${next_args[*]}"
        scp -i "$SSH_KEY" \
            -o ControlMaster=auto \
            -o ControlPath="$SSH_SOCKET" \
            -o ControlPersist=600 \
        -r "$SSH_USER@$SSH_HOST:$file" ./
    fi

    # copying multiple (1+) files
    if [[ "$files_count" -gt 1 ]]; then
        # https://stackoverflow.com/a/21691584/4343719
        scp -i "$SSH_KEY" \
            -o ControlMaster=auto \
            -o ControlPath="$SSH_SOCKET" \
            -o ControlPersist=600 \
        -r "$SSH_USER@$SSH_HOST:${next_args[*]}" ./
    fi
}

ssh_run() {
    # $next_args = next arguments excluding current (array)
    # see for…in loop at the bottom for details
    if [[ -n "${next_args[0]}" ]]; then
        ssh_cmd -t "${next_args[@]}"
    else
        ssh_cmd -t
    fi
}

cmd_run() {
    ssh_cwd
    ssh_cmd -t "${next_args[@]}" \
    | sed -e "s#${SSH_CWD}#${LOCAL_CWD}#g"
}

set_ssh_key_path() {
    read -r -p "Set path to your ssh key [$SSH_PUBKEY]: " ssh_pubkey
    echo ""
    if [[ -n "$ssh_pubkey" ]]; then
        if [[ ! -e "$ssh_pubkey" ]]; then
            red "Config path '$ssh_pubkey' does not exist!"
            exit 66
        fi
        SSH_PUBKEY=ssh_pubkey
    fi
}

i=0

for arg in "$@"; do

    # exclude current and previous args
    # array slicing using $i index
    i=$((i + 1))
    next_args=("${@:$((i+1))}")

    case $arg in
    up)
        echo ""
        echo "Bringing up instance…"
        echo ""

        up
        ;;

    down)
        echo ""
        echo "Bringing down instance…"
        echo ""

        down
        ;;

    reset)
        echo ""
        echo "Re-creating instance…"
        echo ""

        down
        up
        ;;

    sync)
        echo ""
        echo "Syncing local to remote…"
        echo ""

        sync
        ;;

    watch)
        echo ""
        echo "Watching for changes…"
        echo ""

        watch
        ;;

    deps)
        echo ""
        echo "Installing Node dependencies…"
        echo ""

        deps
        ;;

    prep|prepare)
        echo ""
        echo "Sync -> install deps -> watching for changes…"
        echo ""

        echo "Syncing…"
        echo ""
        sync
        echo ""

        echo "Installing Node dependencies…"
        echo ""
        deps
        echo ""

        echo "Watching for changes…"
        echo ""
        watch
        ;;

    ssh)
        ssh_run
        # terminate early
        # all subsequent parameters are passed to function
        # see function ssh() for details
        break;
        ;;

    cmd)
        cmd_run
        # terminate early
        # all subsequent parameters are passed to function
        # see function cmd() for details
        break;
        ;;

    scp)
        copy_from_remote
        # terminate early
        # all subsequent parameters are passed to function
        # see function copy_from_remote() for details
        break
        ;;

    dist)
        copy_from_remote
        ;;

    cp|copy)
        copy_from_local
        # terminate early
        # all subsequent parameters are passed to function
        # see function copy_from_local() for details
        break
        ;;

    host)
        copy_host
        ;;

    config)
        echo ""
        set_ssh_key_path
        generate_config
        ;;

    help)
        echo ""
        echo "up         create dev server *"
        echo "down       destory dev server *"
        echo "reset      re-create dev server *"
        echo "sync       rsync from local to remote *"
        echo "watch      watch local for changes and sync"
        echo "deps       install Node deps on remote *"
        echo "prep[are]  shortcut for sync -> deps -> watch"
        echo "ssh        start interactive ssh session"
        echo "ssh <cmd>  execute command on droplet"
        echo "cmd <cmd>  ssh <cmd> and replace cwd with local"
        echo "scp<path>  copy from remote to local (cwd)"
        echo "copy<path> copy from local to remote (~/.repo/)"
        echo "cp <path>  alias to copy command"
        echo "dist       shortcut to copying dist/ from remote *"
        echo "host       show public ip of remote *"
        echo "config     create config from env var CLOUD_CONFIG *"
        echo "help       show available commands"
        echo ""
        echo "* these commands support chaining, e.g. do.sh up prep sync"
        echo ""
        ;;

    *)
        red "Parameter(s) '$arg' is unsupported! Try 'do.sh help' to see available commands!"
        # http://tldp.org/LDP/abs/html/exitcodes.html
        exit 64
        ;;
esac
done
