#!/bin/bash
# Long-running: forward AeroSpace events to sketchybar as the aerospace_change event.
# Keeps retrying while AeroSpace is not up yet (login order) or after it restarts.
# sketchybarrc kills this script on every reload; take the subscriber down with
# us, otherwise it lives on as an orphaned IPC client inside AeroSpace.

sub=""
trap 'kill "$sub" 2>/dev/null; exit 0' TERM INT

while true; do
  aerospace subscribe --no-send-initial focus-changed focused-workspace-changed window-detected 2>/dev/null \
    > >(while IFS= read -r _; do sketchybar --trigger aerospace_change; done) &
  sub=$!
  wait "$sub"
  sleep 2 &
  wait $!
done
