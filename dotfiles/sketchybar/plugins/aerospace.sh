#!/bin/bash

WHITE=0xffffffff
WHITE_50=0x80ffffff

# Workspace colors
CYAN=0xff89ddff
BLUE=0xff82aaff
PURPLE=0xffc792ea
PINK=0xffff79c6
GREEN=0xffc3e88d

declare -A WORKSPACE_COLORS
WORKSPACE_COLORS=(
  [1]=$CYAN
  [2]=$BLUE
  [3]=$PURPLE
  [4]=$PINK
  [5]=$GREEN
  [6]=$WHITE
  [7]=$WHITE
  [8]=$WHITE
  [9]=$WHITE
)

# Use FOCUSED_WORKSPACE if defined, otherwise check the focused workspace
FW="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

if [ "$1" = "$FW" ]; then
  color="${WORKSPACE_COLORS[$1]:-$WHITE}"
  sketchybar --set "$NAME" icon.color=$color label.color=$color
else
  sketchybar --set "$NAME" icon.color=$WHITE_50 label.color=$WHITE_50
fi
