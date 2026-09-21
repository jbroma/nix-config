{
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile."wezterm/wezterm.lua".text =
    builtins.replaceStrings
      [ "@hackFontDir@" ]
      [ "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack" ]
      (builtins.readFile ../dotfiles/wezterm/wezterm.lua);

  programs.zsh.initContent = lib.mkAfter ''
    if [ -r "/Applications/WezTerm.app/wezterm.sh" ]; then
      source "/Applications/WezTerm.app/wezterm.sh"
    fi
  '';
}
