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
      darwin-rebuild-switch = "sudo ~/.nix/rebuild-and-switch.sh";
      cat = "bat";
      code = "cursor";
    };
  };
}