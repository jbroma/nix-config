#!/bin/bash

# Load system accent color
source "$CONFIG_DIR/plugins/accent_color.sh"

# Nerd Font Font Awesome battery icons (literal unicode)
BATTERY_100=""   # fa-battery-full
BATTERY_90=""    # fa-battery-full
BATTERY_80=""    # fa-battery-three-quarters
BATTERY_70=""    # fa-battery-three-quarters
BATTERY_60=""    # fa-battery-half
BATTERY_50=""    # fa-battery-half
BATTERY_40=""    # fa-battery-quarter
BATTERY_30=""    # fa-battery-quarter
BATTERY_20=""    # fa-battery-empty
BATTERY_10=""    # fa-battery-empty
BATTERY_CHARGING=""  # fa-bolt

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

# Use uniform accent color
case "${PERCENTAGE}" in
  100) ICON=$BATTERY_100 ;;
  9[0-9]) ICON=$BATTERY_90 ;;
  8[0-9]) ICON=$BATTERY_80 ;;
  7[0-9]) ICON=$BATTERY_70 ;;
  6[0-9]) ICON=$BATTERY_60 ;;
  5[0-9]) ICON=$BATTERY_50 ;;
  4[0-9]) ICON=$BATTERY_40 ;;
  3[0-9]) ICON=$BATTERY_30 ;;
  2[0-9]) ICON=$BATTERY_20 ;;
  1[0-9]) ICON=$BATTERY_10 ;;
  *) ICON=$BATTERY_10 ;;
esac

COLOR=$ACCENT_LIGHT

if [[ "$CHARGING" != "" ]]; then
  ICON=$BATTERY_CHARGING
fi

sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="${PERCENTAGE}%"
