{ ... }:

{
  system.defaults.NSGlobalDomain = {
    # Show all file extensions
    AppleShowAllExtensions = true;
  };

  system.defaults.finder = {
    # Show path bar
    ShowPathbar = true;
    # Set default view style to Column View
    FXPreferredViewStyle = "clmv";
    # Keep folders on top when sorting by name
    _FXSortFoldersFirst = true;
    # When performing a search, search the current folder by default
    FXDefaultSearchScope = "SCcf";
    # Disable the warning when changing a file extension
    FXEnableExtensionChangeWarning = false;
  };
}