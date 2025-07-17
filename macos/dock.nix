{ ... }:

{
  system.defaults.dock = {
    autohide = true;
  };

  system.defaults.CustomUserPreferences = {
    NSGlobalDomain = {
      # Sequoia+: Double click window title bar to fill screen
      AppleActionOnDoubleClick = "Fill";
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
        tilesize = 46;
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