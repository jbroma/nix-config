#!/bin/bash

source "$CONFIG_DIR/theme.sh"

# Nerd Font Font Awesome battery icons (literal unicode)
BATTERY_FULL=""           # fa-battery-full
BATTERY_THREE_QUARTERS="" # fa-battery-three-quarters
BATTERY_HALF=""           # fa-battery-half
BATTERY_QUARTER=""        # fa-battery-quarter
BATTERY_EMPTY=""          # fa-battery-empty
BATTERY_CHARGING=""       # fa-bolt

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  100|9[0-9]) ICON=$BATTERY_FULL ;;
  [7-8][0-9]) ICON=$BATTERY_THREE_QUARTERS ;;
  [5-6][0-9]) ICON=$BATTERY_HALF ;;
  [3-4][0-9]) ICON=$BATTERY_QUARTER ;;
  *) ICON=$BATTERY_EMPTY ;;
esac

COLOR=$WHITE

if [[ "$CHARGING" != "" ]]; then
  ICON=$BATTERY_CHARGING
  COLOR=$GREEN
elif [ "$PERCENTAGE" -le 20 ]; then
  COLOR=$RED
elif [ "$PERCENTAGE" -le 40 ]; then
  COLOR=$YELLOW
fi

sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="${PERCENTAGE}%"
