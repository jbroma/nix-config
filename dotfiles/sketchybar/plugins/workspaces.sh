#!/bin/bash
# Refresh every workspace item in one sketchybar call.
# focused: highlighted pill; non-empty: bright icon; empty: dimmed icon.

source "$CONFIG_DIR/theme.sh"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"
occupied=$(aerospace list-workspaces --monitor all --empty no)

args=()
for sid in "${!WORKSPACE_ICONS[@]}"; do
  if [ "$sid" = "$focused" ]; then
    color=$WHITE
    pill=on
  elif grep -qx "$sid" <<<"$occupied"; then
    color=$WHITE_70
    pill=off
  else
    color=$WHITE_50
    pill=off
  fi
  args+=(--set "space.$sid" icon.color=$color label.color=$color background.drawing=$pill)
done

sketchybar "${args[@]}"
