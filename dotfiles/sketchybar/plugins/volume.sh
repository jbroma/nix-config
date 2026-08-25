#!/bin/bash

source "$CONFIG_DIR/theme.sh"

# Scrolling over the item nudges the volume; the volume_change event then redraws it.
if [ "$SENDER" = "mouse.scrolled" ]; then
  step=2
  [ "$SCROLL_DELTA" -lt 0 ] && step=-2
  osascript -e "set volume output volume ((output volume of (get volume settings)) + $step)"
  exit 0
fi

# Nerd Font Font Awesome volume icons (literal unicode)
VOLUME_HIGH="" # U+F028
VOLUME_MED="" # U+F027
VOLUME_LOW="" # U+F026
VOLUME_MUTE="" # U+F026

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
else
  VOLUME=$(osascript -e 'output volume of (get volume settings)')
fi

case "$VOLUME" in
  [6-9][0-9] | 100) ICON=$VOLUME_HIGH COLOR=$WHITE ;;
  [3-5][0-9]) ICON=$VOLUME_MED COLOR=$WHITE ;;
  [1-9] | [1-2][0-9]) ICON=$VOLUME_LOW COLOR=$WHITE ;;
  *) ICON=$VOLUME_MUTE COLOR=$WHITE_50 VOLUME=0 ;;
esac

sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="${VOLUME}%"
