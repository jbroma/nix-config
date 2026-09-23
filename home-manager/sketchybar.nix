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
  # Launch through a script named "sketchybar" instead of /bin/sh, so Login Items shows that
  # name instead of "sh". The store is mounted long before login, so the wait is not needed.
  launchd.agents.sketchybar.waitForNixStore = false;
}
