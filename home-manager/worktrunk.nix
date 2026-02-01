# Worktrunk - Git worktree management
# https://worktrunk.dev
{ ... }:

{
  # User config: ~/.config/worktrunk/config.toml
  xdg.configFile."worktrunk/config.toml".source = ../dotfiles/worktrunk/config.toml;
}
