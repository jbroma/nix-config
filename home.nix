{ 
  config, 
  pkgs, 
  ... 
}:

{
  # List packages you want to install for your user only.
  home.packages = with pkgs; [
    htop
  ];

  home.stateVersion = "25.11";

  programs.zsh = {
    enable = true;
    shellAliases = {
      darwin-rebuild-switch = "~/.nix/rebuild-and-switch.sh";
      ll = "ls -l";
    };
  };

}