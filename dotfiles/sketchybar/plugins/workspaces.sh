#!/bin/bash
# Refresh every workspace item in one sketchybar call.
# focused: highlighted pill; non-empty: icons of the apps in it; empty: dimmed purpose icon.

source "$CONFIG_DIR/theme.sh"
source "$(command -v icon_map.sh)"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
windows=$(aerospace list-windows --all --format '%{workspace}|%{app-name}' | sort -u)

args=()
for sid in "${!WORKSPACE_ICONS[@]}"; do
  icons=""
  while IFS='|' read -r ws app; do
    [ "$ws" = "$sid" ] || continue
    app_icon "$app"
    icons+="$icon_result"
  done <<<"$windows"

  if [ "$sid" = "$focused" ]; then
    color=$WHITE
    pill=on
  elif [ -n "$icons" ]; then
    color=$WHITE_70
    pill=off
  else
    color=$WHITE_50
    pill=off
  fi

  if [ -n "$icons" ]; then
    args+=(--set "space.$sid" icon="$icons" icon.font="$APP_FONT")
  else
    args+=(--set "space.$sid" icon="${WORKSPACE_ICONS[$sid]}" icon.font="$ICON_FONT")
  fi
  args+=(icon.color=$color label.color=$color background.drawing=$pill)
done

sketchybar "${args[@]}"
