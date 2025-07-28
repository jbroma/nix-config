#!/bin/sh

# Use FOCUSED_WORKSPACE if defined, otherwise check the focused workspace
FW="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

if [ "$1" = "$FW" ]; then
  sketchybar --set $NAME label.color=0xffffffff
else
  sketchybar --set $NAME label.color=0xff9a9a9a
fi