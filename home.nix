{
  lib,
  config,
  pkgs,
  type,
  ai,
  ...
}:

let
  # Bootstrap profiles pass ai = null: no AI tool config until the private input is reachable.
  enableAi = ai != null;
in
{
  # Symlink ai flake input to ~/.nix/ai for visibility
  home.file.".nix/ai" = lib.mkIf enableAi {
    source = ai;
  };
  # ~/vault -> the stock iCloud Obsidian vault, so `cd ~/vault` works without remembering the path.
  home.file."vault".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Mobile Documents/iCloud~md~obsidian/Documents/Vault";
  # List packages you want to install for your user only.
  home.packages =
    with pkgs;
    [
      # dev
      agent-browser
      agent-device
      bun
      fd
      fontconfig
      gh
      jq
      htop
      maestro
      pnpm
      sd
      # sketchybar # gets installed on it's own when using home-manager integration
      tree
      choose
      curlie
      nil
      typescript-language-server
      uv
      watchman
      wsmancli
    ]
    ++ lib.optionals (type == "personal") [
      railway
    ];

  home.sessionVariables = {
    FONTCONFIG_FILE = "${config.xdg.configHome}/fontconfig/fonts.conf";
  }
  // lib.optionalAttrs (type == "work") {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  fonts.fontconfig.enable = true;
  xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <include>${pkgs.fontconfig.out}/etc/fonts/fonts.conf</include>
      <include ignore_missing="yes">${config.xdg.configHome}/fontconfig/conf.d</include>
      <dir>/Library/Fonts/Nix Fonts</dir>
    </fontconfig>
  '';

  home.stateVersion = "25.11";

  imports = [
    ./home-manager/zsh.nix
    ./home-manager/git.nix
    ./home-manager/1password.nix
    ./home-manager/wezterm.nix
    ./home-manager/bat.nix
    ./home-manager/fzf.nix
    ./home-manager/oh-my-posh.nix
    ./home-manager/zellij.nix
    ./home-manager/eza.nix
    ./home-manager/vim.nix
    ./home-manager/mise.nix
    ./home-manager/pnpm.nix
    ./home-manager/delta.nix
    ./home-manager/ripgrep.nix
    ./home-manager/sketchybar.nix
    ./home-manager/aerospace.nix
    ./home-manager/mcp-servers.nix
    ./home-manager/llm.nix
    ./home-manager/agent-sandbox.nix
    ./home-manager/vite-plus.nix
    ./home-manager/zed.nix
  ]
  ++ lib.optionals enableAi [
    ./home-manager/ai-instructions.nix
    ./home-manager/cursor.nix
    ./home-manager/claude-code.nix
    ./home-manager/codex.nix
  ];
}
