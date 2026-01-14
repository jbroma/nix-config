#!/bin/bash

# Reads macOS system accent color and exports sketchybar-compatible hex values
# AppleAccentColor values: -1=Graphite, 0=Red, 1=Orange, 2=Yellow, 3=Green, 4=Blue, 5=Purple, 6=Pink
# Not set = Blue (default)

ACCENT_VALUE=$(defaults read -g AppleAccentColor 2>/dev/null)

case "$ACCENT_VALUE" in
  0)  # Red
    ACCENT=0xffff453a
    ACCENT_SOFT=0xffff6961
    ;;
  1)  # Orange
    ACCENT=0xffff9f0a
    ACCENT_SOFT=0xffffb340
    ;;
  2)  # Yellow
    ACCENT=0xffffd60a
    ACCENT_SOFT=0xffffe066
    ;;
  3)  # Green
    ACCENT=0xff30d158
    ACCENT_SOFT=0xff6ee7b7
    ;;
  5)  # Purple
    ACCENT=0xffbf5af2
    ACCENT_SOFT=0xffd4a5ff
    ;;
  6)  # Pink
    ACCENT=0xffff375f
    ACCENT_SOFT=0xffff6b8a
    ;;
  -1) # Graphite
    ACCENT=0xff8e8e93
    ACCENT_SOFT=0xffb0b0b5
    ;;
  *)  # Blue (default, or 4)
    ACCENT=0xff0a84ff
    ACCENT_SOFT=0xff64b5f6
    ;;
esac

export ACCENT
export ACCENT_SOFT
