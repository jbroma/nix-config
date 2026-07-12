{
  lib,
  pkgs,
  type,
  user,
  utils,
  allowedUnfreePackages,
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

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfreePackages;

  environment = {
    # List packages you want to install system-wide.
    systemPackages =
      with pkgs;
      [
        # xcode
        claude-code
        codex-cli
        maestro-studio
        openscreen
        raycast
        google-chrome
        lmstudio
        _1password-gui
        minisim
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
    aerospace = mkLaunchAgent "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
    raycast = mkLaunchAgent "${pkgs.raycast}/Contents/Library/LoginItems/RaycastLauncher.app/Contents/MacOS/RaycastLauncher";
    cleanshot-x = mkLaunchAgent "/Applications/CleanShot X.app/Contents/MacOS/CleanShot X";
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

    remove_nix_app_link() {
      app_link="/Applications/$1.app"

      if [ -L "$app_link" ]; then
        target=$(readlink "$app_link")
        case "$target" in
          "/Applications/Nix Apps/"*)
            rm -f "$app_link"
            ;;
        esac
      fi
    }

    remove_nix_app_link "Android Studio"
    remove_nix_app_link "ChatGPT"
    remove_nix_app_link "Claude"
    remove_nix_app_link "CleanShot X"
    remove_nix_app_link "Codex"
    remove_nix_app_link "Cursor"
    remove_nix_app_link "WezTerm"
    remove_nix_app_link "Zed"

    spotify_update_dir="/Users/${user.username}/Library/Application Support/Spotify/PersistentCache/Update"
    if [ -e "$spotify_update_dir" ]; then
      /usr/bin/chflags -R nouchg "$spotify_update_dir" 2>/dev/null || true
    fi

    brew_as_user() {
      sudo --user=${user.username} --set-home /opt/homebrew/bin/brew "$@"
    }

    if [ -x /opt/homebrew/bin/brew ] \
      && brew_as_user list --cask codex-app >/dev/null 2>&1; then
      brew_as_user uninstall --cask codex-app
    fi

    if [ -x /opt/homebrew/bin/brew ] \
      && brew_as_user list --cask wezterm >/dev/null 2>&1 \
      && ! brew_as_user list --cask wezterm@nightly >/dev/null 2>&1; then
      brew_as_user uninstall --cask wezterm
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

    ensure_app_link "Google Chrome"
    ensure_app_link "1Password"
    ensure_app_link "Slack"
    ensure_app_link "Openscreen"

    sketchybar_homebrew_bin="/opt/homebrew/bin/sketchybar"
    sketchybar_nix_bin="/etc/profiles/per-user/${user.username}/bin/sketchybar"
    if [ -d /opt/homebrew/bin ] && [ -x "$sketchybar_nix_bin" ]; then
      if [ ! -e "$sketchybar_homebrew_bin" ]; then
        ln -s "$sketchybar_nix_bin" "$sketchybar_homebrew_bin"
      elif [ -L "$sketchybar_homebrew_bin" ]; then
        case "$(readlink "$sketchybar_homebrew_bin")" in
          /etc/profiles/per-user/*/bin/sketchybar)
            ln -sf "$sketchybar_nix_bin" "$sketchybar_homebrew_bin"
            ;;
        esac
      fi
    fi
  '';

  # dnsmasq config
  services.dnsmasq.enable = true;
  services.dnsmasq.bind = "127.0.0.1";
  services.dnsmasq.addresses = {
    "test" = "127.0.0.1";
  };

  services.tailscale.enable = true;
}
