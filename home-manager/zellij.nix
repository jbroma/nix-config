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

  # start zellij on ghostty startup
  programs.ghostty = {
    settings = {
      initial-command = "${lib.getExe pkgs.zsh} -l -c zellij -l welcome";
    };
  };
}