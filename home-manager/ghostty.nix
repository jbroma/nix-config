{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      font-family = "FiraCode Nerd Font";
      theme = "catppuccin-mocha";
    }
  };
}