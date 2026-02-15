# Worktrunk - Git worktree management
# https://worktrunk.dev
{
  config,
  lib,
  pkgs,
  ...
}:

let
  worktrunkDotfile = ../dotfiles/worktrunk/config.toml;
  worktrunkConfigPath = "${config.xdg.configHome}/worktrunk/config.toml";
  mergeWorktrunkConfigScript = ../scripts/merge-worktrunk-config.sh;
in
{
  # Keep ~/.config/worktrunk/config.toml mutable:
  # - Bootstrap from dotfile if missing
  # - Otherwise merge only managed keys from dotfile into existing config
  home.activation.worktrunkConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${mergeWorktrunkConfigScript} \
      "${worktrunkDotfile}" \
      "${worktrunkConfigPath}" \
      "${pkgs.remarshal}/bin/remarshal" \
      "${pkgs.jq}/bin/jq"
  '';

  # Shell integration
  programs.zsh.initContent = ''
    eval "$(wt config shell init zsh)"
  '';
}
