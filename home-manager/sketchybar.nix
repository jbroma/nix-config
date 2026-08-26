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
    service = {
      enable = true;
    };
  };
}
