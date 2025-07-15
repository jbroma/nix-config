{ 
  config, 
  pkgs,
  type,
  ... 
}: 

{
  # List packages you want to install for your user only.
  home.packages = with pkgs; [
    fzf
    htop
    tree
  ];

  home.stateVersion = "25.11";

  imports = [
    ./home-manager/zsh.nix
    ./home-manager/git.nix
    ./home-manager/1password.nix
    ./home-manager/fzf.nix
  ];
}