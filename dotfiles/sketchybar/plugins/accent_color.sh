#!/bin/bash

# Reads macOS system accent color and exports sketchybar-compatible hex values
# Provides 4 shades: ACCENT (primary), ACCENT_LIGHT, ACCENT_LIGHTER, ACCENT_LIGHTEST
# AppleAccentColor values: -1=Graphite, 0=Red, 1=Orange, 2=Yellow, 3=Green, 4=Blue, 5=Purple, 6=Pink

ACCENT_VALUE=$(defaults read -g AppleAccentColor 2>/dev/null)

case "$ACCENT_VALUE" in
  0)  # Red
    ACCENT=0xffff453a
    ACCENT_LIGHT=0xffff6b63
    ACCENT_LIGHTER=0xffff918c
    ACCENT_LIGHTEST=0xffffb8b5
    ;;
  1)  # Orange
    ACCENT=0xffff9f0a
    ACCENT_LIGHT=0xffffb340
    ACCENT_LIGHTER=0xffffc770
    ACCENT_LIGHTEST=0xffffdba0
    ;;
  2)  # Yellow
    ACCENT=0xffffd60a
    ACCENT_LIGHT=0xffffe040
    ACCENT_LIGHTER=0xffffea70
    ACCENT_LIGHTEST=0xfffff4a0
    ;;
  3)  # Green
    ACCENT=0xff30d158
    ACCENT_LIGHT=0xff5ade7a
    ACCENT_LIGHTER=0xff84eb9c
    ACCENT_LIGHTEST=0xffaef8be
    ;;
  5)  # Purple
    ACCENT=0xffbf5af2
    ACCENT_LIGHT=0xffcd7ef5
    ACCENT_LIGHTER=0xffdba2f8
    ACCENT_LIGHTEST=0xffe9c6fb
    ;;
  6)  # Pink
    ACCENT=0xffff375f
    ACCENT_LIGHT=0xffff6083
    ACCENT_LIGHTER=0xffff89a7
    ACCENT_LIGHTEST=0xffffb2cb
    ;;
  -1) # Graphite
    ACCENT=0xff8e8e93
    ACCENT_LIGHT=0xffa5a5aa
    ACCENT_LIGHTER=0xffbcbcc1
    ACCENT_LIGHTEST=0xffd3d3d8
    ;;
  *)  # Blue (default, or 4)
    ACCENT=0xff0a84ff
    ACCENT_LIGHT=0xff3d9eff
    ACCENT_LIGHTER=0xff70b8ff
    ACCENT_LIGHTEST=0xffa3d2ff
    ;;
esac

export ACCENT
export ACCENT_LIGHT
export ACCENT_LIGHTER
export ACCENT_LIGHTEST
