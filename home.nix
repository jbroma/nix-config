{ 
  config, 
  pkgs,
  type,
  ... 
}: 

{
  # List packages you want to install for your user only.
  home.packages = with pkgs; [
    bat
    fzf
    htop
    tree
  ];

  home.stateVersion = "25.11";

  imports = [
    ./home-manager/zsh.nix
    ./home-manager/git.nix
    ./home-manager/1password.nix
    ./home-manager/ghostty.nix
    ./home-manager/bat.nix
    ./home-manager/fzf.nix
    ./home-manager/oh-my-posh.nix
  ];
}