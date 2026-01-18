{
  config,
  lib,
  pkgs,
  type,
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

    history = {
      expireDuplicatesFirst = true;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      path = "${config.xdg.dataHome}/zsh/history";
      save = 99999;
      size = 99999;
      share = true;
    };

    initContent = ''
      bindkey "^[[1;5C" forward-word       # Ctrl+Right Arrow
      bindkey "^[[1;5D" backward-word      # Ctrl+Left Arrow
    '';

    localVariables = {
      # enforce using aliases
      YSU_HARDCORE = 1;
    };

    shellAliases = {
      darwin-rebuild-switch = "sudo ~/.nix/scripts/rebuild-and-switch.sh ~/.nix#${type}";
      darwin-cleanup = "sudo nix-collect-garbage --delete-older-than 7d";
      flake-update = "(cd ~/.nix && nix flake update)";
      cat = "bat";
      code = "cursor";
      # Screenshot-optimized terminal for Twitter photos
      ghostty-screenshot = "ghostty --config-file=~/.config/ghostty/screenshot-config";
      # Restart Claude Island app
      island-restart = "killall 'Claude Island'; open -a 'Claude Island'";
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
