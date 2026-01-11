#!/bin/bash

GREEN=0xffc3e88d
YELLOW=0xffffcb6b
ORANGE=0xfff78c6c
RED=0xffff5370
BLUE=0xff82aaff

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

case "${PERCENTAGE}" in
  100) ICON=$BATTERY_100; COLOR=$GREEN ;;
  9[0-9]) ICON=$BATTERY_90; COLOR=$GREEN ;;
  8[0-9]) ICON=$BATTERY_80; COLOR=$GREEN ;;
  7[0-9]) ICON=$BATTERY_70; COLOR=$GREEN ;;
  6[0-9]) ICON=$BATTERY_60; COLOR=$GREEN ;;
  5[0-9]) ICON=$BATTERY_50; COLOR=$YELLOW ;;
  4[0-9]) ICON=$BATTERY_40; COLOR=$YELLOW ;;
  3[0-9]) ICON=$BATTERY_30; COLOR=$ORANGE ;;
  2[0-9]) ICON=$BATTERY_20; COLOR=$ORANGE ;;
  1[0-9]) ICON=$BATTERY_10; COLOR=$RED ;;
  *) ICON=$BATTERY_10; COLOR=$RED ;;
esac

if [[ "$CHARGING" != "" ]]; then
  ICON=$BATTERY_CHARGING
  COLOR=$BLUE
fi

sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="${PERCENTAGE}%"
