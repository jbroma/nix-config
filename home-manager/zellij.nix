{
  pkgs,
  lib,
  ...
}:

{
  programs.zellij = {
    enable = true;
    settings = {
      show_startup_tips = false;
      theme = "ao";
    };
  };

  # Uncomment to auto-start zellij in Ghostty.
  # programs.ghostty = {
  #   settings = {
  #     initial-command = "${lib.getExe pkgs.zsh} -l -c zellij -l welcome";
  #   };
  # };
}
