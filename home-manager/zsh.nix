{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.zsh = {
    enable = true;
    shellAliases = {
      # rebuild shortcut
      darwin-rebuild-switch = "sudo ~/.nix/rebuild-and-switch.sh";
      # basic utils
      cat = "bat";
      ll = "ls -l";
      # editors
      code = "cursor";
    };
  };
}