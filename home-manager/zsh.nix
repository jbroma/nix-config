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
      darwin-cleanup = "sudo nix-collect-garbage --delete-older-than 7d";
      flake-update = "(cd ~/.nix && nix flake update)";
      cat = "bat";
      code = "cursor";
    };
  };
}
