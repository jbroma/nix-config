{ ... }:

{
  system.defaults.NSGlobalDomain = {
    # Show all file extensions
    AppleShowAllExtensions = true;
  };

  system.defaults.finder = {
    # Allow quitting via ⌘ + Q;
    QuitMenuItem = true;
    # Show status bar
    ShowStatusBar = true;
    # Show path bar
    ShowPathbar = true;
    # Set default view style to List View
    FXPreferredViewStyle = "Nlsv";  
    # Keep folders on top when sorting by name
    _FXSortFoldersFirst = true;
    # When performing a search, search the current folder by default
    FXDefaultSearchScope = "SCcf";
    # Disable the warning when changing a file extension
    FXEnableExtensionChangeWarning = false;
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
      # Disable animations in Finder
      DisableAllAnimations = true;
      # Sidebar order
      SidebarZoneOrder1 = [
        "favorites"
        "devices"
        "locations"
        "icloud_drive"
        "tags"
      ];
    };
  };
}