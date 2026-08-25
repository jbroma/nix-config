{
  pkgs,
  ...
}:

let
  sketchybar = pkgs.writeShellApplication {
    name = "sketchybar";
    text = ''
      exec /opt/homebrew/bin/sketchybar "$@"
    '';
  };
in
{
  programs.sketchybar = {
    enable = true;
    package = sketchybar;
    config = {
      source = ../dotfiles/sketchybar;
      recursive = true;
    };
    # icon_map.sh: app name -> sketchybar-app-font ligature, used by the plugins.
    extraPackages = [ pkgs.sketchybar-app-font ];
    service = {
      enable = true;
    };
  };
}
