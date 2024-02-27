#!/bin/bash

# Default WATCHER_ENABLED to false if not set
WATCHER_ENABLED=${WATCHER_ENABLED:-false}

echo "Watcher Enabled: $WATCHER_ENABLED" # Debug line to check the environment variable

# Assuming 'pi' is the non-root user, adjust as necessary
# Ensure this user exists in your Docker image
USER=pi

# Function to run commands as non-root user
run_as_user() {
    su - "$USER" -c "$1"
}

# Function to copy initial example files to /app/configs if not already done
copy_initial_configs() {
    local flag_file="/app/configs/.initial_copy_done"

    if [ ! -f "$flag_file" ]; then
        if [ -f "/app/config.json.example" ]; then
            run_as_user "cp -n \"/app/config.json.example\" \"/app/configs/config.json\""
        fi

        if [ -f "/app/colors/scoreboard.json" ]; then
            run_as_user "cp -n \"/app/colors/scoreboard.json\" \"/app/configs/scoreboard.json\""
        fi

        for file in /app/coordinates/*.json /app/coordinates/*.json.example; do
            if [ -f "$file" ]; then
                run_as_user "cp -n \"$file\" \"/app/configs/\""
            fi
        done

        run_as_user "touch \"$flag_file\""
    fi
}

# Function to copy specific files to their respective directories with backup
copy_specific_files() {
    if [ -f "/app/configs/config.json" ]; then
        run_as_user "mv -f \"/app/config.json\" \"/app/config.json.bak\""
        run_as_user "cp -f \"/app/configs/config.json\" \"/app/\""
    fi

    if [ -f "/app/configs/scoreboard.json" ]; then
        run_as_user "mv -f \"/app/colors/scoreboard.json\" \"/app/colors/scoreboard.json.bak\""
        run_as_user "cp -f \"/app/configs/scoreboard.json\" \"/app/colors/\""
    fi

    for file in /app/configs/*.json; do
        filename=$(basename "$file")
        if [[ $filename =~ w(32|64|128)h(32|64).json(.example|.sample)? ]]; then
            run_as_user "mv -f \"/app/coordinates/$filename\" \"/app/coordinates/$filename.bak\""
            run_as_user "cp -f \"$file\" \"/app/coordinates/\""
        fi
    done
}

# Adjusted to perform file operations as non-root user
copy_initial_configs
copy_specific_files

# Define the command to start main.py with updated path
main_command="python3 /app/main.py"

# Function to start main.py with dynamically constructed command line
start_main_py() {
    additional_params=""
    while IFS='=' read -r name value ; do
        if [[ $name == PARAM_* ]]; then
            param_name=$(echo "$name" | sed -e 's/^PARAM_//g' | tr '[:upper:]' '[:lower:]' | sed -e 's/_/-/g')
            additional_params+="--$param_name=$value "
        fi
    done < <(env)

    echo "Running command: sudo $main_command $additional_params" # Using sudo for commands requiring root
    sudo $main_command $additional_params > /proc/1/fd/1 2>/proc/1/fd/2 &
    MAIN_PY_PID=$!
}

# Remaining script continues unchanged...



# Function to kill main.py specifically
kill_main_py() {
    if [ ! -z "$MAIN_PY_PID" ]; then
        echo "Killing the existing main.py process..."
        kill "$MAIN_PY_PID" && wait "$MAIN_PY_PID"
    fi
}

# Function to start the watcher
start_watcher() {
    if [ "$WATCHER_ENABLED" = "true" ]; then
        inotifywait -m -e modify -e move -e create -e delete "/app/configs" "/app/colors" "/app/coordinates" |
        while read -r directory events filename; do
            copy_specific_files
            just_filename=$(basename "${directory}${filename}")
            echo "Change detected $just_filename. The application will restart."
            kill_main_py
            sleep 1
            start_main_py
        done
    else
        echo "Watcher is disabled."
    fi
}

# Kill any existing instances of main.py
kill_main_py

# Start main.py
start_main_py

# Start the watcher in the background if enabled
if [ "$WATCHER_ENABLED" = "true" ]; then
    start_watcher &
fi

# Wait indefinitely to prevent the container from exiting
wait
