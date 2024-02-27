#!/bin/bash

# Default WATCHER_ENABLED to false if not set
WATCHER_ENABLED=${WATCHER_ENABLED:-false}

echo "Watcher Enabled: $WATCHER_ENABLED" # Debug line to check the environment variable

# Function to move specific files to their respective directories
move_specific_files() {
    # Move scoreboard.json to /app/colors/
    if [ -f "/app/configs/scoreboard.json" ]; then
        echo "Moving scoreboard.json to /app/colors/"
        mv -f "/app/configs/scoreboard.json" "/app/colors/"
    fi

    # Move certain JSON files to /app/coordinates/
    for file in /app/configs/*.json; do
        filename=$(basename "$file")
        if [[ $filename =~ w(32|64|128)h(32|64).json(.example|.sample)? ]]; then
            echo "Moving $filename to /app/coordinates/"
            mv -f "$file" "/app/coordinates/"
        fi
    done
}

# Move specific files before starting main.py or watcher
move_specific_files

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

    echo "Running command: $main_command $additional_params"
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
    if [ "$WATCHER_ENABLED" = "true" ]; then
        inotifywait -m -e modify -e move -e create -e delete "/app" "/app/colors/" "/app/coordinates/" |
        while read -r directory events filename; do
            move_specific_files
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
