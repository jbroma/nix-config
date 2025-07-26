{ ... }:

{
  system.defaults.NSGlobalDomain = {
    # Enable keyboard navigation
    AppleKeyboardUIMode = 3;
    # Boost keyboard speed and disable any auto correction
    KeyRepeat = 2;
    InitialKeyRepeat = 15;
    # Disable press-and-hold for keys in favor of key repeat
    ApplePressAndHoldEnabled = false;
    # Disable automatic capitalisation
    NSAutomaticCapitalizationEnabled = false;
    # Disable smart dashes
    NSAutomaticDashSubstitutionEnabled = false;
    # Disable automatic period substitution
    NSAutomaticPeriodSubstitutionEnabled = false;
    # Disable smart quotes
    NSAutomaticQuoteSubstitutionEnabled = false;
    # Disable auto-correct
    NSAutomaticSpellingCorrectionEnabled = false;
  };
}