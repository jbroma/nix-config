#!/bin/bash

# Load system accent color
source "$CONFIG_DIR/plugins/accent_color.sh"

# Nerd Font Material Design battery icons (literal unicode)
BATTERY_100="󰁹"   # nf-md-battery
BATTERY_90="󰂂"    # nf-md-battery_90
BATTERY_80="󰂁"    # nf-md-battery_80
BATTERY_70="󰂀"    # nf-md-battery_70
BATTERY_60="󰁿"    # nf-md-battery_60
BATTERY_50="󰁾"    # nf-md-battery_50
BATTERY_40="󰁽"    # nf-md-battery_40
BATTERY_30="󰁼"    # nf-md-battery_30
BATTERY_20="󰁻"    # nf-md-battery_20
BATTERY_10="󰁺"    # nf-md-battery_10
BATTERY_CHARGING="󰂄"  # nf-md-battery_charging

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
