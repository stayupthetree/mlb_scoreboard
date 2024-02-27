#!/bin/bash

# Default WATCHER_ENABLED to false if not set
WATCHER_ENABLED=${WATCHER_ENABLED:-false}

# Retrieve UID and GID from environment variables, defaulting to 1000 if not provided
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Watcher Enabled: $WATCHER_ENABLED" # Debug line to check the environment variable
echo "Using PUID: $PUID, PGID: $PGID" # Debug line to confirm PUID and PGID

# Function to copy initial example files to /app/configs if not already done
copy_initial_configs() {
    local flag_file="/app/configs/.initial_copy_done"

    if [ ! -f "$flag_file" ]; then
        if [ -f "/app/config.json.example" ]; then
            cp -n "/app/config.json.example" "/app/configs/config.json"
            chown $PUID:$PGID "/app/configs/config.json"
        fi

        if [ -f "/app/colors/scoreboard.json" ]; then
            cp -n "/app/colors/scoreboard.json" "/app/configs/scoreboard.json"
            chown $PUID:$PGID "/app/configs/scoreboard.json"
        fi

        for file in /app/coordinates/*.json /app/coordinates/*.json.example; do
            if [ -f "$file" ]; then
                cp -n "$file" "/app/configs/"
                chown $PUID:$PGID "/app/configs/$(basename "$file")"
            fi
        done

        touch "$flag_file"
        chown $PUID:$PGID "$flag_file"
    fi
}

copy_specific_files() {
    if [ -f "/app/configs/config.json" ]; then
        if [ -f "/app/config.json" ]; then
            mv -f "/app/config.json" "/app/config.json.bak"
            chown $PUID:$PGID "/app/config.json.bak"
        fi
        cp -f "/app/configs/config.json" "/app/"
        chown $PUID:$PGID "/app/config.json"
    fi

    if [ -f "/app/configs/scoreboard.json" ]; then
        if [ -f "/app/colors/scoreboard.json" ]; then
            mv -f "/app/colors/scoreboard.json" "/app/colors/scoreboard.json.bak"
            chown $PUID:$PGID "/app/colors/scoreboard.json.bak"
        fi
        cp -f "/app/configs/scoreboard.json" "/app/colors/"
        chown $PUID:$PGID "/app/colors/scoreboard.json"
    fi

    for file in /app/configs/*.json; do
        filename=$(basename "$file")
        if [[ $filename =~ w(32|64|128)h(32|64).json(.example|.sample)? ]]; then
            if [ -f "/app/coordinates/$filename" ]; then
                mv -f "/app/coordinates/$filename" "/app/coordinates/$filename.bak"
                chown $PUID:$PGID "/app/coordinates/$filename.bak"
            fi
            cp -f "$file" "/app/coordinates/"
            chown $PUID:$PGID "/app/coordinates/$filename"
        fi
    done
}

copy_initial_configs
copy_specific_files

main_command="python3 /app/main.py"

start_main_py() {
    additional_params=""
    while IFS='=' read -r name value ; do
        if [[ $name == PARAM_* ]]; then
            param_name=$(echo "$name" | sed -e 's/^PARAM_//g' | tr '[:upper:]' '[:lower:]' | sed -e 's/_/-/g')
            additional_params+="--$param_name=$value "
        fi
    done < <(env)

    $main_command $additional_params > /proc/1/fd/1 2>/proc/1/fd/2 &
    MAIN_PY_PID=$!
}

kill_main_py() {
    if [ ! -z "$MAIN_PY_PID" ]; then
        kill "$MAIN_PY_PID" && wait "$MAIN_PY_PID"
    fi
}

start_watcher() {
    if [ "$WATCHER_ENABLED" = "true" ]; then
        while true; do
            # Wait for significant changes (ignoring temporary files)
            CHANGE_DETECTED=0
            inotifywait -q -e modify -e move -e create -e delete --exclude '.*(~|\.swp)$' "/app/configs" "/app/colors" "/app/coordinates" |
            while read -r directory events filename; do
                echo "Detected event: $directory, $events, $filename" # Debugging output
                # Check if the file is not a temporary or backup file
                if [[ ! $filename =~ .*~$ ]] && [[ ! $filename =~ ^\..* ]]; then
                    echo "Change detected for file: $filename" # More debugging output
                    CHANGE_DETECTED=1
                    break
                fi
            done

            if [[ $CHANGE_DETECTED -eq 1 ]]; then
                echo "Detected changes. Restarting application after debounce period."
                # Wait for a debounce period to ensure all related changes are accounted for
                sleep 2
                
                copy_specific_files
                kill_main_py
                start_main_py
            fi
        done
    else
        echo "Watcher is disabled."
    fi
}




kill_main_py
start_main_py

if [ "$WATCHER_ENABLED" = "true" ]; then
    start_watcher &
fi

wait
