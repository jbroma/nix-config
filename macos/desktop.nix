{
  lib,
  type,
  ...
}:

{
  system.defaults.NSGlobalDomain = {
    # Enable subpixel font rendering on non-Apple LCDs
    AppleFontSmoothing = 1;
    # Hide menu bar
    _HIHideMenuBar = true;
    # Disable wallpaper tinting in windows
    AppleReduceDesktopTinting = true;
  };

  system.defaults.dock = {
    orientation = "left";
    tilesize = 36;
    # Automatically hide and show the Dock, without the delay
    autohide = true;
    autohide-delay = 0.0;
    # Disable automatic rearrangement of Spaces
    mru-spaces = false;
    # Don't animate opening applications from the Dock
    launchanim = false;
    mineffect = "scale";
    show-recents = false;
    # Show indicator lights for open applications in the Dock
    show-process-indicators = true;
    # Bottom right hot corner: 1 = disabled
    wvous-br-corner = 1;

    # workaround for aerospace mission control view
    # https://nikitabobko.github.io/AeroSpace/guide#a-note-on-mission-control
    expose-group-apps = true;

    persistent-apps = [
      "/System/Applications/Apps.app"
      "/Applications/Nix Apps/Google Chrome.app"
      "/Applications/Xcode.app"
      "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
      "/Applications/WezTerm.app"
      "/Applications/Cursor.app"
      "/Applications/Zed.app"
      "/Applications/ChatGPT.app"
      "/Applications/Spotify.app"
      "/Applications/Discord.app"
    ]
    ++ lib.optionals (type == "work") [
      "/Applications/Slack.app"
    ];
  };

  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    # Sequoia+: Double click window title bar to fill screen
    AppleActionOnDoubleClick = "Fill";
  };
}
