#!/bin/bash

# Load system accent color
source "$CONFIG_DIR/plugins/accent_color.sh"

WHITE_50=0x80ffffff

# Nerd Font Material Design volume icons (literal unicode)
VOLUME_HIGH="󰕾"     # nf-md-volume-high
VOLUME_MED="󰖀"      # nf-md-volume-medium
VOLUME_LOW="󰕿"      # nf-md-volume-low
VOLUME_MUTE="󰖁"     # nf-md-volume-off

# Get current volume on init or from event
if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
else
  VOLUME=$(osascript -e 'output volume of (get volume settings)')
fi

case "$VOLUME" in
  [6-9][0-9]|100) ICON=$VOLUME_HIGH; COLOR=$ACCENT ;;
  [3-5][0-9]) ICON=$VOLUME_MED; COLOR=$ACCENT ;;
  [1-9]|[1-2][0-9]) ICON=$VOLUME_LOW; COLOR=$ACCENT ;;
  *) ICON=$VOLUME_MUTE; COLOR=$WHITE_50; VOLUME=0 ;;
esac

sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="${VOLUME}%"
