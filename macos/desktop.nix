{
  pkgs,
  type,
  ...
}:

{
  system.defaults.NSGlobalDomain = {
    # Enable subpixel font rendering on non-Apple LCDs
    AppleFontSmoothing = 1;
  };

  system.defaults.dock = {
    autohide = true;

    persistent-apps = [
      "/System/Applications/Launchpad.app"
      "${pkgs.google-chrome}/Applications/Google Chrome.app"
      "/System/Applications/Calendar.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Notes.app"
      "${pkgs.xcode}"
      "${pkgs.xcode}/Contents/Developer/Applications/Simulator.app"
      "${pkgs.ghostty}/Applications/Ghostty.app"
      "${pkgs.code-cursor}/Applications/Cursor.app"
      "/Applications/Slack.app"
      "${pkgs.discord}/Applications/Discord.app"
      "${pkgs.spotify}/Applications/Spotify.app"
    ];
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
