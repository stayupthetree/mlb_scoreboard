#!/bin/bash

# Default WATCHER_ENABLED to false if not set
WATCHER_ENABLED=${WATCHER_ENABLED:-false}

echo "Watcher Enabled: $WATCHER_ENABLED" # Debug line to check the environment variable

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

    # Echo the full command for debugging
    echo "Running command: $main_command $additional_params"

    # Redirect output of main.py to stdout/stderr of PID 1 and execute it
    $main_command $additional_params > /proc/1/fd/1 2>/proc/1/fd/2 &
    MAIN_PY_PID=$!
}

# Function to kill main.py specifically
kill_main_py() {
    if [ ! -z "$MAIN_PY_PID" ]; then
        echo "Killing the existing main.py process..."
        kill "$MAIN_PY_PID" && wait "$MAIN_PY_PID"
    fi
}

# Function to start the watcher
start_watcher() {
    # Check if watcher is enabled
    if [ "$WATCHER_ENABLED" = "true" ]; then
        # Update paths for config.json, coordinates, and colors
        inotifywait -m -e modify -e move -e create -e delete "/app/config.json" "/app/coordinates/" "/app/colors/" |
        while read -r directory events filename; do
            # Extract just the filename from the path
            just_filename=$(basename "${directory}${filename}")
            echo "Config change detected $just_filename. The MLB Scoreboard will restart."
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

# Start the watcher
if [ "$WATCHER_ENABLED" = "true" ]; then
    start_watcher &
fi

# Wait indefinitely to prevent the container from exiting
wait
