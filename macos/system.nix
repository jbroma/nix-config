{ ... }:

{
  system.defaults.NSGlobalDomain = {
    # Disable automatic termination of inactive apps
    NSDisableAutomaticTermination = true;
  };

  system.defaults.screensaver = {
    # Require password immediately after sleep or screen saver begins
    askForPassword = 1;
    askForPasswordDelay = 0;
  };

  system.defaults.LaunchServices = {
    # Disable the "Are you sure you want to open this application?" dialog
    LSQuarantine = false;
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.printer" = {
      PrintingPrefs = {
        # Automatically quit printer app once the print jobs complete
        "Quit When Finished" = true;
      }
    };

    "com.apple.systempreferences" = {
      # Disable Resume system-wide
      NSQuitAlwaysKeepsWindows = false;
    };
  };
}