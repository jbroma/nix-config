{
  config,
  lib,
  pkgs,
  ...
}:

let
  vitePlusHome = "${config.home.homeDirectory}/.vite-plus";
  setupVitePlusScript = ../scripts/setup-vite-plus.sh;
in
{
  home.sessionVariables = {
    VITE_PLUS_HOME = "$HOME/.vite-plus";
  };

  # Make the managed Vite+ bin directory available in shells and GUI-launched sessions.
  home.sessionPath = [ "${config.home.homeDirectory}/.vite-plus/bin" ];

  # Source the upstream-generated env file so `vp env use` can mutate the current shell session.
  programs.zsh.initContent = lib.mkAfter ''
    if [ -f "$HOME/.vite-plus/env" ]; then
      . "$HOME/.vite-plus/env"
    fi
  '';

  home.activation.vitePlusBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${setupVitePlusScript} \
      "${vitePlusHome}" \
      "${pkgs.vite-plus.version}" \
      "${pkgs.vite-plus}/bin/vp"
  '';
}
