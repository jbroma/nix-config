{
  pkgs,
  ai,
  ...
}:

{
  # Symlink ai flake input to ~/.nix/ai for visibility
  home.file.".nix/ai".source = ai;
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
    jq
    htop
    eza
    mise
    pnpm
    ripgrep
    sd
    # sketchybar # gets installed on it's own when using home-manager integration
    tree
    choose
    curlie
    nil
    typescript-language-server
    watchman
    zellij
    dcg
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
    ./home-manager/eza.nix
    ./home-manager/vim.nix
    ./home-manager/mise.nix
    ./home-manager/delta.nix
    ./home-manager/ripgrep.nix
    ./home-manager/cursor.nix
    ./home-manager/sketchybar.nix
    ./home-manager/aerospace.nix
    ./home-manager/claude-code.nix
    ./home-manager/gemini.nix
    ./home-manager/mcp-servers.nix
    ./home-manager/zed.nix
  ];
}
