#!/bin/bash
# Palette, fonts and workspace icons shared by sketchybarrc and the plugins.

# Liquid glass islands (see glass_island in sketchybarrc): a frosted base, two
# translucent layers hugging the top edge for a top-to-bottom gradient, a bright
# hairline rim nudged up and a dark one nudged down for a lit top / shaded bottom.
ISLAND_FILL=0x1fffffff
ISLAND_GLOW=0x0fffffff
ISLAND_RIM_HI=0x8cffffff
ISLAND_RIM_LO=0x33000000
ISLAND_SHADOW=0x66000000
# The focused workspace's capsule inside the island.
FOCUS_FILL=0x47ffffff
WHITE=0xffffffff
WHITE_90=0xe6ffffff
WHITE_50=0x80ffffff
GREEN=0xff7bd88f
YELLOW=0xfffce566
RED=0xfffc618d

FONT="Hack Nerd Font"
ICON_FONT="$FONT:Bold:13.0"
LABEL_FONT="$FONT:Bold:11.0"
# Ligature font: ":google_chrome:" renders as the Chrome logo (sketchybar-app-font).
APP_FONT="sketchybar-app-font:Regular:14.0"

# App name -> app font ligature. Needs icon_map.sh sourced (it defines __icon_map).
app_icon() {
  case "$1" in
    # The font's wezterm glyph is a wide "$W" wordmark; use the plain terminal one.
    WezTerm) icon_result=":terminal:" ;;
    *) __icon_map "$1" ;;
  esac
}

# Nerd Font Font Awesome icons (literal unicode)
ICON_APPLE="" # U+F179
ICON_VOLUME="" # U+F028
ICON_WIFI="" # U+F1EB

WORKSPACES=(1 2 3 4 5 6 7 8 9)

# What each workspace is for; shown while it is empty.
WORKSPACE_ICONS=(
  [1]="" # U+F108 terminal
  [2]="" # U+F0AC browser
  [3]="" # U+F120 ChatGPT / Zed
  [4]="" # U+F121 Cursor
  [5]="" # U+F07B misc
  [6]="" # U+F249 Notes
  [7]="" # U+F198 Slack
  [8]="" # U+F1FF Discord
  [9]="" # U+F1BC Spotify
)
