{
  pkgs,
  type,
  ...
}:

{
  system.defaults.NSGlobalDomain = {
    # Enable subpixel font rendering on non-Apple LCDs
    AppleFontSmoothing = 1;
    # Hide menu bar
    _HIHideMenuBar = true;
  };

  system.defaults.dock = {
    autohide = true;

    # workaround for aerospace mission control view
    # https://nikitabobko.github.io/AeroSpace/guide#a-note-on-mission-control
    expose-group-apps = true;

    persistent-apps = [
      "/System/Applications/Apps.app"
      "/Applications/Safari.app"
      "/Applications/Nix Apps/Google Chrome.app"
      "/System/Applications/Calendar.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Notes.app"
      "/Applications/Xcode.app"
      "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
      "/Applications/Nix Apps/Ghostty.app"
      "/Applications/Nix Apps/Cursor.app"
      "/Applications/Nix Apps/Spotify.app"
      "/Applications/Nix Apps/Discord.app"
    ]
    ++ (
      if type == "work" then
        [
          "/Applications/Slack.app"
        ]
      else
        [ ]
    );
  };

  system.defaults.CustomUserPreferences = {
    NSGlobalDomain = {
      # Sequoia+: Double click window title bar to fill screen
      AppleActionOnDoubleClick = "Fill";
      # Disable wallpaper tinting in windows
      AppleReduceDesktopTinting = true;
    };

    "com.apple.dock" = {
      # Set Dock orientation
      orientation = "left";
      # Disable automatic rearrangement of Spaces
      mru-spaces = 0;
      # Automatically hide and show the Dock
      autohide = true;
      # Remove the auto-hiding Dock delay
      autohide-delay = 0;
      # Set the icon size of Dock items
      tilesize = 36;
      # Don't animate opening applications from the Dock
      launchanim = false;
      # Change minimize/maximize window effect
      mineffect = "scale";
      # Remove the Dock recents section
      show-recents = 0;
      # Set bottom right screen corner to no-op
      wvous-br-corner = 0;
      # Show indicator lights for open applications in the Dock
      show-process-indicators = true;
    };
  };
}
