#!/bin/sh

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set $NAME label.color=0xffffffff
else
  sketchybar --set $NAME label.color=0x779a9a9a
fi