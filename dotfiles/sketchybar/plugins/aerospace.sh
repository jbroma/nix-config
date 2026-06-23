#!/bin/bash

WHITE=0xfff7f1ff
GREY=0xff8b888f
PILL_BG=0x5a363537
PILL_BORDER=0x2ab0b8cc

# Use FOCUSED_WORKSPACE if defined, otherwise check the focused workspace
FW="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

if [ "$1" = "$FW" ]; then
  sketchybar --set "$NAME" \
    icon.color=$WHITE \
    label.color=$WHITE \
    background.drawing=on \
    background.color=$PILL_BG \
    background.border_color=$PILL_BORDER
else
  sketchybar --set "$NAME" \
    icon.color=$GREY \
    label.color=$GREY \
    background.drawing=off
fi
