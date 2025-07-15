{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    enableZshIntegration = true;
    settings = {
      font-family = "FiraCode Nerd Font Mono Reg";
      font-family-bold = "FiraCode Nerd Font Mono Bold";
      font-synthetic-style = [
        "italic"
        "bold-italic"
      ];
      font-size = 14;
      theme = "GitHub Dark";
    };
  };
}