#!/bin/bash
# Refresh every workspace item in one sketchybar call.
# Each pill: the workspace number, then the icons of the apps open in it.
# focused: bright outline; non-empty: hairline outline; empty: dim number and purpose icon.

source "$CONFIG_DIR/theme.sh"
source "$(command -v icon_map.sh)"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
windows=$(aerospace list-windows --all --format '%{workspace}|%{app-name}' | sort -u)

args=()
for sid in "${WORKSPACES[@]}"; do
  icons=""
  while IFS='|' read -r ws app; do
    [ "$ws" = "$sid" ] || continue
    app_icon "$app"
    icons+="$icon_result"
  done <<<"$windows"

  if [ "$sid" = "$focused" ]; then
    color=$WHITE
    outline=$OUTLINE_FOCUS
  elif [ -n "$icons" ]; then
    color=$WHITE_70
    outline=$OUTLINE
  else
    color=$WHITE_50
    outline=$OUTLINE_DIM
  fi

  if [ -n "$icons" ]; then
    args+=(--set "space.$sid" label="$icons" label.font="$APP_FONT")
  else
    args+=(--set "space.$sid" label="${WORKSPACE_ICONS[$sid]}" label.font="$ICON_FONT")
  fi
  args+=(icon.color=$color label.color=$color background.border_color=$outline)
done

sketchybar --animate tanh 10 "${args[@]}"
