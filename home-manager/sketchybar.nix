{
  ...
}:

{
  programs.sketchybar = {
    enable = true;
  };

  home.file.".config/sketchybar" = {
    source = ../dotfiles/sketchybar;
    recursive = true;
  };
}
