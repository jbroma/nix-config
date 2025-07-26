{ ... }:

{
  system.defaults.NSGlobalDomain = {
    # Enable subpixel font rendering on non-Apple LCDs
    AppleFontSmoothing = 1;
  };

  system.defaults.CustomUserPreferences = {
    NSGlobalDomain = {
      # Sequoia+: Double click window title bar to fill screen
      AppleActionOnDoubleClick = "Fill";
    };
  };
}