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

  programs.ghostty = {
    settings = {
      initial-command = "${lib.getExe pkgs.zsh} -l -c zellij -l welcome";
    };
  };
}