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
      font-family = "Hack Nerd Font";
      font-family-bold = "Hack Nerd Font";
      font-synthetic-style = [
        "italic"
        "bold-italic"
      ];
      font-size = 14;
      keybind = [
        "shift+enter=text:\\n"
      ];
      maximize = true;
      quit-after-last-window-closed = true;
      theme = "GitHub Dark";
    };
  };
}
