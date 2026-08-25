#!/bin/bash
# Refresh every workspace item in one sketchybar call.
# focused: highlighted pill; non-empty: icon of its main app, "+N" for the other
# apps in it; empty: dimmed purpose icon.
# The main app is the focused window's app on the focused workspace, otherwise
# the first window AeroSpace lists there.

source "$CONFIG_DIR/theme.sh"
source "$(command -v icon_map.sh)"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
focused_app=$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null)
windows=$(aerospace list-windows --all --format '%{workspace}|%{app-name}')

args=()
for sid in "${!WORKSPACE_ICONS[@]}"; do
  apps=()
  while IFS='|' read -r ws app; do
    [ "$ws" = "$sid" ] || continue
    case " ${apps[*]} " in *" $app "*) continue ;; esac
    apps+=("$app")
  done <<<"$windows"

  icons=""
  extra=""
  if [ "${#apps[@]}" -gt 0 ]; then
    main="${apps[0]}"
    [ "$sid" = "$focused" ] && [ -n "$focused_app" ] && main="$focused_app"
    app_icon "$main"
    icons="$icon_result"
    [ "${#apps[@]}" -gt 1 ] && extra=" +$((${#apps[@]} - 1))"
  fi

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
  args+=(label="$sid$extra" icon.color=$color label.color=$color background.drawing=$pill)
done

sketchybar "${args[@]}"
