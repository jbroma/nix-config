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
      cat = "bat";
      code = "cursor";
    };
  };
}