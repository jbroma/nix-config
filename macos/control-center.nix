{ ... }:

{
  # menu bar clock settings
  system.defaults.menuExtraClock = {
    FlashDateSeparators = false;
    IsAnalog   = false;
    Show24Hour = true;
    ShowAMPM   = false;
    ShowDate   = 1;
    ShowDayOfMonth = true;
    ShowDayOfWeek  = false;
    ShowSeconds    = false;
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.controlcenter" = {
      BatteryShowPercentage = false;
    };

    "com.apple.Spotlight" = {
      MenuItemHidden = true;
    };
  };
}