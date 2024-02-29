# System dependencies stage
FROM python:3.9 AS base

RUN apt-get update && apt-get install -y \
  git \
  build-essential \
  libssl-dev \
  libffi-dev \
  libsdl2-dev \
  libxml2-dev \
  libxslt-dev \
  libjpeg-dev \
  zlib1g-dev

# Builder stage
FROM python:3.9-slim AS builder

# Copy system dependencies from base stage
COPY --from=base /usr/local/lib /usr/local/lib

# Install Python tools and libraries
RUN pip install --no-cache-dir wheel

# Install Python dependencies
RUN pip install --no-cache-dir feedparser==6.0.10 'MLB_StatsAPI>=1.6.1' pyowm==3.3.0 'tzlocal==4.2' Pillow>=10.0.1

# Clone the GitHub repository
WORKDIR /build
RUN git clone https://github.com/MLB-LED-Scoreboard/mlb-led-scoreboard.git

# Set up a Python virtual environment
RUN python3 -m venv venv
ENV PATH="/build/venv/bin:$PATH"

# Clone and build the rpi-rgb-led-matrix library
RUN cd mlb-led-scoreboard && \
  mkdir submodules && \
  cd submodules && \
  git clone https://github.com/hzeller/rpi-rgb-led-matrix.git matrix && \
  cd matrix && \
  make build-python PYTHON=$(which python3) -j4 && \
  make install-python PYTHON=$(which python3) -j4

# Final stage
FROM python:3.9-slim

# Install runtime dependencies
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
