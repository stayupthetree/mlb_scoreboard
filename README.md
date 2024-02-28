# MLB Scoreboard Docker Container for Raspberry Pi

This Docker container allows you to run an MLB scoreboard on a Raspberry Pi.

## Prerequisites

- Docker and Docker Compose installed on your system.
- ARMv8 architecture, or ARMv7 for older Raspberry Pi models.

## Getting Started

First, ensure you have Docker and Docker Compose installed on your system. Clone this repository or copy the `docker-compose.yml` contents into a new file in your preferred directory.

### Docker Compose

Below is the `docker-compose.yml` file configured for this service:

```yaml
version: '3.8'

services:
  scoreboard:
    image: ghcr.io/stayupthetree/mlb_scoreboard:armv7 #change to armv7 for older pi
    container_name: scoreboard
    privileged: true
    devices:
      - /dev/gpiomem:/dev/gpiomem
    volumes:
      - ./config/:/app/configs/
    environment:
      - PUID=1000
      - PGID=1000
      - WATCHER_ENABLED=true
      - PARAM_LED_GPIO_MAPPING=adafruit-hat-pwm
      - PARAM_LED_BRIGHTNESS=20
      - PARAM_LED_SLOWDOWN_GPIO=4
      - PARAM_LED_COLS=64
      - PARAM_LED_ROWS=32
      - TZ=America/New_York
    restart: unless-stopped
```

## Environment Variables

Watcher Variable
- `WATCHER_ENABLED=true` will monitor configs like config.json, scoreboard.json, and the coordinate files for changes and automatically restart the scoreboard if any are detected. This is currently a little wonky and may restart just by opening a file with nano

The following environment variables can be set to configure the LED matrix:

- `PARAM_LED_ROWS` is equivalent to `--led-rows` (Number of display rows. Default: 32)
- `PARAM_LED_COLS` is equivalent to `--led-cols` (Number of panel columns. Default: 32)
- `PARAM_LED_CHAIN` is equivalent to `--led-chain` (Daisy-chained boards. Default: 1)
- `PARAM_LED_PARALLEL` is equivalent to `--led-parallel` (Parallel chains. Default: 1)
- `PARAM_LED_PWM_BITS` is equivalent to `--led-pwm-bits` (Bits used for PWM. Default: 11)
- `PARAM_LED_BRIGHTNESS` is equivalent to `--led-brightness` (Sets brightness level. Default: 100)
- `PARAM_LED_GPIO_MAPPING` is equivalent to `--led-gpio-mapping` (Hardware Mapping. Default: regular)
- `PARAM_LED_SCAN_MODE` is equivalent to `--led-scan-mode` (Scan mode. Default: 1 for Interlaced)
- `PARAM_LED_PWM_LSB_NANOSECONDS` is equivalent to `--led-pwm-lsb-nanosecond` (Base time-unit for the LSB in nanoseconds. Default: 130)
- `PARAM_LED_SHOW_REFRESH` is equivalent to `--led-show-refresh` (Shows the refresh rate of the LED panel)
- `PARAM_LED_LIMIT_REFRESH` is equivalent to `--led-limit-refresh` (Limit the refresh rate of the LED panel)
- `PARAM_LED_SLOWDOWN_GPIO` is equivalent to `--led-slowdown-gpio` (Slow down writing to GPIO. Default: 1)
- `PARAM_LED_NO_HARDWARE_PULSE` is equivalent to `--led-no-hardware-pulse` (Don't use hardware pin-pulse generation)
- `PARAM_LED_RGB_SEQUENCE` is equivalent to `--led-rgb-sequence` (RGB sequence. Default: RGB)
- `PARAM_LED_PIXEL_MAPPER` is equivalent to `--led-pixel-mapper` (Apply pixel mappers)
- `PARAM_LED_ROW_ADDR_TYPE` is equivalent to `--led-row-addr-type` (Row address type. Default: 0)
- `PARAM_LED_MULTIPLEXING` is equivalent to `--led-multiplexing` (Multiplexing type. Default: 0)

## Notes

- For Raspberry Pi 3 and earlier models, use the `armv7` tag.
- For Raspberry Pi 4 and later models, use the `armv8` tag.
- Ensure that you have the necessary hardware interfaces and permissions set up on your Raspberry Pi to communicate with the LED matrix.

