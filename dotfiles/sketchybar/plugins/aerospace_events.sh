#!/bin/bash
# Long-running: forward AeroSpace events to sketchybar as the aerospace_change event.
# Keeps retrying while AeroSpace is not up yet (login order) or after it restarts.

while true; do
  aerospace subscribe --no-send-initial focus-changed focused-workspace-changed window-detected 2>/dev/null |
    while IFS= read -r _; do
      sketchybar --trigger aerospace_change
    done
  sleep 2
done
