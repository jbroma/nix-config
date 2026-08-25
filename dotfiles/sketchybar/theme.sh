#!/bin/bash
# Palette, fonts and workspace icons shared by sketchybarrc and the plugins.

# Islands: tinted, blurred glass slabs with a light rim.
BAR_BG=0x4a181a22
BAR_BORDER=0x33ffffff
# Pills inside them: frosted white, lit from the rim. Alpha is the whole effect.
GLASS_FILL=0x12ffffff
GLASS_FILL_DIM=0x08ffffff
GLASS_FILL_FOCUS=0x30ffffff
OUTLINE=0x2effffff
OUTLINE_DIM=0x14ffffff
OUTLINE_FOCUS=0x8cffffff
WHITE=0xfff7f1ff
WHITE_70=0xb3f7f1ff
WHITE_50=0x998b888f
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
