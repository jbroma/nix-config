{
  pkgs,
  ...
}:

{
  programs.sketchybar = {
    enable = true;
    package = pkgs.sketchybar;
    config = {
      source = ../dotfiles/sketchybar;
      recursive = true;
    };
    service = {
      enable = true;
    };
  };
}
