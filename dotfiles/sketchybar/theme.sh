#!/bin/bash
# Palette, fonts and workspace icons shared by sketchybarrc and the plugins.

BAR_BG=0x4a181a22
BAR_BORDER=0x2ab0b8cc
# Pills are outlines on the glass, not fills.
OUTLINE=0x40b0b8cc
OUTLINE_DIM=0x1fb0b8cc
OUTLINE_FOCUS=0xd9f7f1ff
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
ICON_CPU="" # U+F2DB
ICON_APPLE="" # U+F179
ICON_VOLUME="" # U+F028
ICON_WIFI="" # U+F1EB

WORKSPACES=(1 2 3 4 5 6 7 8 9)
