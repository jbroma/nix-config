#!/bin/bash

# Load system accent color
source "$CONFIG_DIR/plugins/accent_color.sh"

WHITE_50=0x80ffffff

# Use FOCUSED_WORKSPACE if defined, otherwise check the focused workspace
FW="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

if [ "$1" = "$FW" ]; then
  sketchybar --set "$NAME" icon.color=$ACCENT_LIGHT label.color=$ACCENT_LIGHT
else
  sketchybar --set "$NAME" icon.color=$WHITE_50 label.color=$WHITE_50
fi
