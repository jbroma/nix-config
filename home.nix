{
  config,
  pkgs,
  type,
  ...
}:

{
  # List packages you want to install for your user only.
  home.packages = with pkgs; [
    # dev
    aerospace
    bat
    bun
    delta
    fd
    fzf
    gh
    htop
    lsd
    mise
    pnpm
    ripgrep
    # sketchybar # gets installed on it's own when using home-manager integration
    tree
    watchman
    zellij
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
    ./home-manager/zellij.nix
    ./home-manager/lsd.nix
    ./home-manager/vim.nix
    ./home-manager/mise.nix
    ./home-manager/delta.nix
    ./home-manager/ripgrep.nix
    ./home-manager/cursor.nix
    ./home-manager/sketchybar.nix
    ./home-manager/aerospace.nix
    ./home-manager/claude-code.nix
  ];
}
