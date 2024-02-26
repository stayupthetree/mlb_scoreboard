# Builder stage
FROM python:3.9-slim-bookworm as builder

# Install system and build dependencies, including Python tools and libraries
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    libssl-dev \
    libffi-dev \
    libsdl2-dev \
    libxml2-dev \
    libxslt-dev \
    libjpeg-dev \
    zlib1g-dev \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-pillow \
    python3-tk \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory for the build stage
WORKDIR /build

# Clone the GitHub repository
RUN git clone https://github.com/MLB-LED-Scoreboard/mlb-led-scoreboard.git

# Set up a Python virtual environment
RUN python3 -m venv venv
ENV PATH="/build/venv/bin:$PATH"

# Install Python dependencies
RUN pip install --no-cache-dir wheel \
    && pip install --no-cache-dir feedparser==6.0.10 'MLB_StatsAPI>=1.6.1' pyowm==3.3.0 'tzlocal==4.2' Pillow>=10.0.1

# Clone and build the rpi-rgb-led-matrix library
RUN cd mlb-led-scoreboard && \
    mkdir submodules && \
    cd submodules && \
    git clone https://github.com/hzeller/rpi-rgb-led-matrix.git matrix && \
    cd matrix && \
    make build-python PYTHON=$(which python3) && \
    make install-python PYTHON=$(which python3)

# Final stage
FROM python:3.9-slim-bookworm

# Install runtime dependencies necessary for the application
RUN apt-get update && apt-get install -y \
    inotify-tools \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /build/venv ./venv

# Copy the application files directly to /app
COPY --from=builder /build/mlb-led-scoreboard/ ./

# Copy and ensure the entrypoint script is executable
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# Activate virtual environment
ENV PATH="/app/venv/bin:$PATH"

ENTRYPOINT ["/app/entrypoint.sh"]
