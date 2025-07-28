{
  ...
}:

{
  programs.sketchybar = {
    enable = true;
    config = {
      source = ../dotfiles/sketchybar;
      recursive = true;
    };
    configType = "bash";
    service = {
      enable = false;
    };
  };
}
