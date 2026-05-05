{
  lib,
  pkgs,
  type,
  user,
  utils,
  ai,
  enableAi ? true,
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
      "claude-desktop"
      "codex-app"
      "codex-cli"
      "cursor"
      "1password-gui"
      "1password"
      "raycast"
      "discord"
      "orbstack"
      "obsidian"
      "slack"
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
        claude-desktop
        codex-app
        codex-cli
        maestro-studio
        zed-editor
        raycast
        google-chrome
        cursor
        _1password-gui
        minisim
        spotify
        discord
        git
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
        exiftool
        zstd
        ast-grep
        nmap
        podman
        orbstack
        yq-go
        remarshal
        # libs
        libyaml
      ]
      # Work machines have these apps installed outside Nix.
      ++ lib.optionals (type == "personal") [
        obsidian
      ]
      # Work-only app managed by Nix.
      ++ lib.optionals (type == "work") [
        slack
      ];

    variables = {
      ANDROID_HOME = "$HOME/Library/Android/sdk";
      # Add Android SDK tools to PATH (appended so Nix tools take precedence)
      PATH = "$PATH:$HOME/.local/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin";
    };
  };

  fonts.packages = with pkgs; [
    atkinson-hyperlegible
    atkinson-hyperlegible-next
    dm-sans
    figtree
    ibm-plex
    inter
    noto-fonts
    nerd-fonts.fira-code
    nerd-fonts.hack
    nunito-sans
    plus-jakarta-sans
    public-sans
    recursive
    source-sans
    work-sans
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
        enableAi
        ;
    };
  };

  # apps to launch on login
  launchd.user.agents = {
    raycast = mkLaunchAgent "${pkgs.raycast}/Contents/Library/LoginItems/RaycastLauncher.app/Contents/MacOS/RaycastLauncher";
    cleanshot-x = mkLaunchAgent "${pkgs.cleanshot-x}/Applications/CleanShot X.app/Contents/MacOS/CleanShot X";
  };

  # enable touch id for sudo
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

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

  system.activationScripts.postActivation.text = lib.mkAfter ''
    ensure_app_link() {
      nix_app="/Applications/Nix Apps/$1.app"
      app_link="/Applications/$1.app"

      if [ -e "$nix_app" ]; then
        if [ -L "$app_link" ]; then
          rm -f "$app_link"
          ln -s "$nix_app" "$app_link"
        elif [ ! -e "$app_link" ]; then
          ln -s "$nix_app" "$app_link"
        fi
      fi
    }

    ensure_app_link "Cursor"
    ensure_app_link "Google Chrome"
    ensure_app_link "1Password"
    ensure_app_link "Slack"
  '';

  # dnsmasq config
  services.dnsmasq.enable = true;
  services.dnsmasq.bind = "127.0.0.1";
  services.dnsmasq.addresses = {
    "test" = "127.0.0.1";
  };
}
