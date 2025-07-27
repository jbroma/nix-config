{
  config,
  lib,
  pkgs,
  ...
}:

{
  # install plugin packages
  home.packages = with pkgs; [
    zsh-fzf-tab
    zsh-autosuggestions
    zsh-fast-syntax-highlighting
    zsh-you-should-use
  ];

  programs.zsh = {
    enable = true;

    localVariables = {
      # enforce using aliases
      YSU_HARDCORE = 1;
    };

    shellAliases = {
      darwin-rebuild-switch = "sudo ~/.nix/rebuild-and-switch.sh";
      darwin-cleanup = "sudo nix-collect-garbage --delete-older-than 7d";
      flake-update = "(cd ~/.nix && nix flake update)";
      cat = "bat";
      code = "cursor";
    };

    plugins = [
      {
        # Must be before plugins zsh-autosuggestions && fast-syntax-highlighting
        name = "zsh-fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
      }
      {
        name = "zsh-you-should-use";
        src = pkgs.zsh-you-should-use;
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
      }
    ];

  };
}
