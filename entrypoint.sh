#!/bin/bash

# Default WATCHER_ENABLED to false if not set
WATCHER_ENABLED=${WATCHER_ENABLED:-false}

echo "Watcher Enabled: $WATCHER_ENABLED" # Debug line to check the environment variable

# Function to copy initial example files to /app/configs if not already done
copy_initial_configs() {
    # Create a flag file to indicate the initial copy has been completed
    local flag_file="/app/configs/.initial_copy_done"

    if [ ! -f "$flag_file" ]; then
        # Copy the example config file if it exists
        if [ -f "/app/config.json.example" ]; then
            cp -n "/app/config.json.example" "/app/configs/config.json"
        fi

        # Copy the scoreboard example file if it exists
        if [ -f "/app/colors/scoreboard.json" ]; then
            cp -n "/app/colors/scoreboard.json" "/app/configs/scoreboard.json"
        fi

        # Copy any .json or .json.example files from /app/coordinates
        for file in /app/coordinates/*.json /app/coordinates/*.json.example; do
            if [ -f "$file" ]; then
                cp -n "$file" "/app/configs/"
            fi
        done

        # Create the flag file to prevent future copying
        touch "$flag_file"
    fi
}

# Function to copy specific files to their respective directories with backup
copy_specific_files() {
    # Copy and backup config.json to /app/
    if [ -f "/app/configs/config.json" ]; then
        if [ -f "/app/config.json" ]; then
            echo "Backing up config.json to config.json.bak"
            mv -f "/app/config.json" "/app/config.json.bak"
        fi
        echo "Copying config.json to /app/"
        cp -f "/app/configs/config.json" "/app/"
    fi

    # Copy and backup scoreboard.json to /app/colors/
    if [ -f "/app/configs/scoreboard.json" ]; then
        if [ -f "/app/colors/scoreboard.json" ]; then
            echo "Backing up scoreboard.json to scoreboard.json.bak"
            mv -f "/app/colors/scoreboard.json" "/app/colors/scoreboard.json.bak"
        fi
        echo "Copying scoreboard.json to /app/colors/"
        cp -f "/app/configs/scoreboard.json" "/app/colors/"
    fi

    # Copy and backup certain JSON files to /app/coordinates/
    for file in /app/configs/*.json; do
        filename=$(basename "$file")
        if [[ $filename =~ w(32|64|128)h(32|64).json(.example|.sample)? ]]; then
            if [ -f "/app/coordinates/$filename" ]; then
                echo "Backing up $filename to $filename.bak"
                mv -f "/app/coordinates/$filename" "/app/coordinates/$filename.bak"
            fi
            echo "Copying $filename to /app/coordinates/"
            cp -f "$file" "/app/coordinates/"
        fi
    done
}

# Run initial copying of example configs if it's the first run
copy_initial_configs

# Copy specific files before starting main.py or watcher
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
