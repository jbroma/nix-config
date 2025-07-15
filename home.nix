{ 
  config, 
  pkgs,
  type,
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
      darwin-rebuild-switch = "sudo ~/.nix/rebuild-and-switch.sh";
      code = "cursor";
      ll = "ls -l";
    };
  };

  imports = [
    ./home-manager/git.nix
    ./home-manager/1password.nix
  ];
}