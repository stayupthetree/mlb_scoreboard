#!/bin/bash

# Define the command to start main.py
main_command="python3 /app/mlb-led-scoreboard/main.py"

# Function to start main.py with dynamically constructed command line
start_main_py() {
    additional_params=""
    while IFS='=' read -r name value ; do
        if [[ $name == PARAM_* ]]; then
            param_name=$(echo "$name" | sed -e 's/^PARAM_//g' | tr '[:upper:]' '[:lower:]' | sed -e 's/_/-/g')
            additional_params+="--$param_name=$value "
        fi
    done < <(env)

    # Redirect output of main.py to stdout/stderr of PID 1
    $main_command $additional_params > /proc/1/fd/1 2>/proc/1/fd/2 &
    MAIN_PY_PID=$!
}

kill_main_py() {
    if [ ! -z "$MAIN_PY_PID" ]; then
        echo "Killing the existing main.py process..."
        kill "$MAIN_PY_PID" && wait "$MAIN_PY_PID"
    fi
}

start_watcher() {
    inotifywait -m -e modify -e move -e create -e delete "/app/mlb-led-scoreboard/config.json" "/app/mlb-led-scoreboard/coordinates/" "/app/mlb-led-scoreboard/colors/" |
    while read -r directory events filename; do
        # Extract just the filename from the path
        just_filename=$(basename "${directory}${filename}")
        echo "Config change detected $just_filename. The MLB Scoreboard will restart."
        kill_main_py
        sleep 1
        start_main_py
    done
}

kill_main_py
start_main_py
start_watcher &

wait