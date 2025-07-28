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
    extraPackages = [
      pkgs.aerospace
    ];
    service = {
      enable = true;
    };
  };
}
