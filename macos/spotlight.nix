{ ... }:

{
  # Hide Spotlight from menu bar
  system.defaults.CustomUserPreferences = {
    "com.apple.Spotlight" = {
      MenuItemHidden = true;
    };
  };

  # Disable Spotlight indexing on all volumes
  system.activationScripts.postActivation.text = ''
    echo "Disabling Spotlight indexing..."
    sudo mdutil -a -i off &>/dev/null || true
  '';
}
