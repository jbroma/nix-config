{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto-update = "off";
      cursor-style = "underline";
      font-family = "FiraCode Nerd Font Mono Reg";
      font-family-bold = "FiraCode Nerd Font Mono Bold";
      font-synthetic-style = [
        "italic"
        "bold-italic"
      ];
      font-size = 14;
      maximize = true;
      quit-after-last-window-closed = true;
      theme = "GitHub Dark";
    };
  };
}