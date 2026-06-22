{
  lib,
  ...
}:

{
  xdg.configFile."wezterm/wezterm.lua".source = ../dotfiles/wezterm/wezterm.lua;

  programs.zsh.initContent = lib.mkAfter ''
    if [ -r "/Applications/WezTerm.app/wezterm.sh" ]; then
      source "/Applications/WezTerm.app/wezterm.sh"
    fi
  '';
}
