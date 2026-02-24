{
  lib,
  pkgs,
  type,
  user,
  utils,
  ai,
  ...
}:

let
  mkLaunchAgent = path: {
    serviceConfig = {
      Disabled = false;
      ProgramArguments = [ path ];
      RunAtLoad = true;
    };
  };
in
{
  # use Determinate Nix daemon
  nix.enable = false;

  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-users = [
      "root"
      user.username
    ];
    keep-going = true;
    keep-failed = true;
    keep-outputs = true;
    show-trace = true;
    sandbox = true;
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      # "Xcode.app"
      "google-chrome"
      "claude-code"
      "codex-app"
      "codex-cli"
      "cursor"
      "1password-gui"
      "1password"
      "raycast"
      "discord"
      "ngrok"
      "spotify"
      # vscode extensions
      "vscode-extension-mhutchie-git-graph"
    ];

  # https://github.com/NixOS/nixpkgs/pull/486721 - Darwin updater broken
  nixpkgs.config.permittedInsecurePackages = [
    "google-chrome-144.0.7559.97"
  ];

  environment = {
    # List packages you want to install system-wide.
    systemPackages =
      with pkgs;
      [
        # xcode
        android-studio
        cleanshot-x
        claude-code
        codex-app
        codex-cli
        codex-monitor
        zed-editor
        raycast
        minisim
        handy
        claude-island
        spotify
        git
        ghostty
        oh-my-posh
        nerd-fonts.fira-code
        nerd-fonts.hack
        nixfmt
        cmake
        ninja
        mkcert
        vim
        gnupg
        dnsmasq
        zstd
        ast-grep
        nmap
        yq-go
        remarshal
        # libs
        libyaml
      ]
      # These apps are installed outside Nix in the work profile.
      ++ lib.optionals (type == "personal") [
        google-chrome
        cursor
        discord
        _1password-gui
      ]
      ++ lib.optionals (type == "work") [ ngrok ];

    variables = {
      ANDROID_HOME = "$HOME/Library/Android/sdk";
      # Add Android SDK tools to PATH (appended so Nix tools take precedence)
      PATH = "$PATH:$HOME/.local/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin";
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user.username} = import ./home.nix;
    extraSpecialArgs = {
      inherit
        type
        user
        utils
        ai
        ;
    };
  };

  # apps to launch on login
  launchd.user.agents = {
    raycast = mkLaunchAgent "${pkgs.raycast}/Contents/Library/LoginItems/RaycastLauncher.app/Contents/MacOS/RaycastLauncher";
    claude-island = mkLaunchAgent "${pkgs.claude-island}/Applications/Claude Island.app/Contents/MacOS/Claude Island";
    cleanshot-x = lib.mkIf (type == "work") (
      mkLaunchAgent "${pkgs.cleanshot-x}/Applications/CleanShot X.app/Contents/MacOS/CleanShot X"
    );
  };

  # enable touch id for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # macos preferences
  imports = [
    ./macos/control-center.nix
    ./macos/desktop.nix
    ./macos/finder.nix
    ./macos/keyboard.nix
    ./macos/siri.nix
    ./macos/spotlight.nix
    ./macos/system.nix
  ];

  system.primaryUser = user.username;

  system.stateVersion = 4;

  users.users.${user.username} = {
    name = user.username;
    home = "/Users/${user.username}";
  };

  # install xcode command line tools if not installed
  system.activationScripts.preActivation.text = ''
    if ! xcode-select --version 2>/dev/null; then
      xcode-select --install
    fi
  '';

  # dnsmasq config
  services.dnsmasq.enable = true;
  services.dnsmasq.bind = "127.0.0.1";
  services.dnsmasq.addresses = {
    "test" = "127.0.0.1";
  };
}
