# Worktrunk - Git worktree management
# https://worktrunk.dev
{ ... }:

{
  # User config: ~/.config/worktrunk/config.toml
  xdg.configFile."worktrunk/config.toml".source = ../dotfiles/worktrunk/config.toml;

  # Shell integration
  programs.zsh.initContent = ''
    eval "$(wt config shell init zsh)"
  '';
}
