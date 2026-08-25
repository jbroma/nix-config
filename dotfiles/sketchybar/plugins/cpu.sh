#!/bin/bash
# CPU load as a sparkline (graph item) plus a percentage.
# ps %cpu is a short decaying average per process, which is plenty for a trend line.

load=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%d", s}')
cores=$(sysctl -n hw.ncpu)
pct=$((load / cores))
[ "$pct" -gt 100 ] && pct=100

sketchybar --push "$NAME" "$(printf '0.%02d' "$pct")" --set "$NAME" label="${pct}%"
