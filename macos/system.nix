{ ... }:

{
  system.defaults.NSGlobalDomain = {
    # Set dark mode
    AppleInterfaceStyle = "Dark";
    # Use metric units
    AppleMetricUnits = 1;
    # Use Celsius for temperature units
    AppleTemperatureUnit = "Celsius";
    # Show scroll bars when scrolling
    AppleShowScrollBars = "WhenScrolling";
    # Disable automatic termination of inactive apps
    NSDisableAutomaticTermination = true;
    # Expand save panel by default
    NSNavPanelExpandedStateForSaveMode = true;
    NSNavPanelExpandedStateForSaveMode2 = true;
  };

  system.defaults.screensaver = {
    # Require password immediately after sleep or screen saver begins
    askForPassword = true;
    askForPasswordDelay = 0;
  };

  # workaround for aerospace with multiple displays
  # https://nikitabobko.github.io/AeroSpace/guide#a-note-on-displays-have-separate-spaces
  system.defaults.spaces = {
    spans-displays = true;
  };

  system.defaults.LaunchServices = {
    # Disable the "Are you sure you want to open this application?" dialog
    LSQuarantine = false;
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.print.PrintingPrefs" = {
      # Automatically quit printer app once the print jobs complete
      "Quit When Finished" = true;
    };

    "com.apple.desktopservices" = {
      # Avoid creating .DS_Store files on network or USB volumes
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };

    # Prevent Photos from opening automatically when devices are plugged in
    "com.apple.ImageCapture".disableHotPlug = true;

    "com.apple.systempreferences" = {
      # Disable Resume system-wide
      NSQuitAlwaysKeepsWindows = false;
    };
  };
}
