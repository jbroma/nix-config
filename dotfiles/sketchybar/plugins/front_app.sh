#!/bin/bash
# Focused app: its sketchybar-app-font icon plus name.

source "$(command -v icon_map.sh)"

if [ "$SENDER" = "front_app_switched" ]; then
  app="$INFO"
else
  app="$(aerospace list-windows --focused --format '%{app-name}')"
fi

__icon_map "$app"
sketchybar --set "$NAME" icon="$icon_result" label="$app"
