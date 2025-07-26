{ 
  lib, 
  ...
}:

let
  # Helper function to generate NSStatusItem visibility attributes
  nsStatusItemVisible = items:
    lib.attrsets.mapAttrs' (name: value: {
      name = "NSStatusItem Visible ${name}";
      value = value;
    }) items;
in
{
  # menu bar clock settings
  system.defaults.menuExtraClock = {
    IsAnalog   = false;
    Show24Hour = true;
    ShowAMPM   = false;
    ShowDate   = 1;
    ShowDayOfMonth = true;
    ShowDayOfWeek  = true;
    ShowSeconds    = true;
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.controlcenter" = nsStatusItemVisible {
      Battery = 0;
      BentoBox = 1;
      Clock = 1;
      FocusModes = 1;
      NowPlaying = 0;
      Sound = 1;
      WiFi = 1;
    };

    "com.apple.menuextra.clock" = {
      FlashDateSeparators = true;
    };

    "com.apple.spotlight" = {
      MenuItemHidden = true;
    };
  };
}