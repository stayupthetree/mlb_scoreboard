# Use the official Debian slim image as the base image
FROM debian:12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    sudo \
    python3 \
    inotify-tools \
    python3-pip \
    python3-venv \
    cmake \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-mixer-dev \
    libsdl2-ttf-dev \
    libportmidi-dev \
    libswscale-dev \
    libavformat-dev \
    libavcodec-dev \
    python3-dev \
    python3-pillow \
    python3-tk \
    libxml2-dev \
    libxslt-dev \
    libsdl2-mixer-2.0-0 \
    libsdl2-image-2.0-0 \
    libsdl2-2.0-0 \
    libsdl2-ttf-2.0-0 \
    libopenjp2-7 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container to /app
WORKDIR /app

# Clone the GitHub repository
RUN git clone https://github.com/MLB-LED-Scoreboard/mlb-led-scoreboard.git

# Change the working directory to the cloned repository's directory
WORKDIR /app/mlb-led-scoreboard

# Create a Python virtual environment and activate it
RUN python3 -m venv venv
ENV PATH="/app/mlb-led-scoreboard/venv/bin:$PATH"

# Install the specified Python packages
RUN pip3 install --no-cache-dir feedparser==6.0.10 'MLB_StatsAPI>=1.6.1' pyowm==3.3.0 'RGBMatrixEmulator>=0.8.4' tzlocal==4.2

# Clone and install the rpi-rgb-led-matrix library
RUN echo "Running rgbmatrix installation..." && \
    mkdir submodules && \
    cd submodules && \
    git clone https://github.com/hzeller/rpi-rgb-led-matrix.git matrix && \
    cd matrix && \
    make build-python PYTHON=$(which python3) && \
    sudo make install-python PYTHON=$(which python3)

# Copy the entrypoint script into the container and ensure it's executable
COPY entrypoint.sh /app/mlb-led-scoreboard/entrypoint.sh
RUN chmod +x /app/mlb-led-scoreboard/entrypoint.sh

# Create a non-root user and switch to it
RUN useradd -m dockeruser && echo "dockeruser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/dockeruser

# It's important to switch to the non-root user after all commands that require root access have been executed
#COPY watcher.sh /watcher.sh
#RUN chmod +x /watcher.sh



ENTRYPOINT ["/app/mlb-led-scoreboard/entrypoint.sh"]