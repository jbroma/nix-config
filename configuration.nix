{
  lib,
  pkgs,
  type,
  user,
  ai,
  ...
}:

let
  allowedUnfreePackages = [
    # "Xcode.app"
    "1password"
    "1password-gui"
    "claude-code"
    "codex-cli"
    "google-chrome"
    "lmstudio"
    "maestro-studio"
    "obsidian"
    "orbstack"
    "raycast"
    "slack"
    "vscode-extension-mhutchie-git-graph"
  ];

  mkLaunchAgent = path: {
    serviceConfig = {
      Disabled = false;
      ProgramArguments = [ path ];
      RunAtLoad = true;
    };
  };
in
{
  # Determinate Nix owns /etc/nix/nix.conf and the daemon, so `nix.settings` is
  # ignored; user settings go in the nix.custom.conf it includes.
  nix.enable = false;
  environment.etc."nix/nix.custom.conf".text = ''
    trusted-users = root ${user.username}
    keep-going = true
    show-trace = true
  '';

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfreePackages;

  environment = {
    # List packages you want to install system-wide.
    systemPackages =
      with pkgs;
      [
        # xcode
        codex-cli
        maestro-studio
        openscreen
        raycast
        google-chrome
        lmstudio
        _1password-gui
        minisim
        # root needs git for the git+ssh flake input during darwin-rebuild
        git
        nixfmt
        cmake
        ninja
        mkcert
        gnupg
        dnsmasq
        exiftool
        zstd
        ast-grep
        nmap
        podman
        orbstack
        yq-go
        # libs
        libyaml
      ]
      # Work machines have these apps installed outside Nix.
      ++ lib.optionals (type == "personal") [
        obsidian
      ]
      # Work-only tools and apps managed by Nix.
      ++ lib.optionals (type == "work") [
        air
        caddy
        cloudflared
        doppler
        gh-poi
        gnutar
        go
        google-cloud-sdk
        pinact
        pulumi
        sentry-cli
        slack
        similarity
        tuist
        usql
      ];

    variables = {
      ANDROID_HOME = "$HOME/Library/Android/sdk";
      # Add Android SDK tools to PATH (appended so Nix tools take precedence)
      PATH = "$PATH:$HOME/.local/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin";
    };
  };

  homebrew = {
    enable = true;
    brews = [
      "felixkratz/formulae/sketchybar"
      "malpern/tap/sketchybar-toggle"
    ];
    casks = [
      "android-studio"
      "chatgpt"
      "claude"
      "cleanshot"
      "cursor"
      "nikitabobko/tap/aerospace"
      "spotify"
      "wezterm@nightly"
      "zed"
    ]
    ++ lib.optionals (type == "personal") [
      "nordvpn"
    ];
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
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
      inherit type user ai;
    };
  };

  # apps to launch on login
  launchd.user.agents = {
    aerospace = mkLaunchAgent "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
    raycast = mkLaunchAgent "${pkgs.raycast}/Contents/Library/LoginItems/RaycastLauncher.app/Contents/MacOS/RaycastLauncher";
    cleanshot-x = mkLaunchAgent "/Applications/CleanShot X.app/Contents/MacOS/CleanShot X";
  };

  security = {
    pki.certificateFiles = lib.optionals (type == "personal") [ ./homelab-ca.crt ];

    # enable touch id for sudo
    pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };
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

  system.activationScripts.postActivation.text = lib.mkAfter (
    ''
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

      ensure_app_link "Google Chrome"
      ensure_app_link "1Password"
      ensure_app_link "Slack"
      ensure_app_link "Openscreen"
    ''
    + lib.optionalString (type == "personal") ''
      homelab_ca=${./homelab-ca.crt}
      if ! /usr/bin/security verify-cert -c "$homelab_ca" >/dev/null 2>&1; then
        /usr/bin/security add-trusted-cert -d -r trustRoot \
          -k /Library/Keychains/System.keychain "$homelab_ca"
      fi
    ''
  );

  # dnsmasq config
  services.dnsmasq.enable = true;
  services.dnsmasq.bind = "127.0.0.1";
  services.dnsmasq.addresses = {
    "test" = "127.0.0.1";
  };

  services.tailscale.enable = true;
}
