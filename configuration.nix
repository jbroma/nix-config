{
  lib,
  pkgs,
  type,
  user,
  ai,
  ...
}:

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
      "cursor"
      "1password-gui"
      "1password"
      "raycast"
      "discord"
      "spotify"
      # vscode extensions
      "vscode-extension-mhutchie-git-graph"
    ];

  environment = {
    # List packages you want to install system-wide.
    systemPackages = with pkgs; [
      # xcode
      android-studio
      google-chrome
      cleanshot-x
      claude-code
      cursor
      # zed-editor
      raycast
      minisim
      discord
      spotify
      _1password-gui
      git
      ghostty
      oh-my-posh
      nerd-fonts.fira-code
      nerd-fonts.hack
      nixfmt-rfc-style
      mkcert
      vim
      gnupg
      dnsmasq
      zstd
      ast-grep
      nmap
      # libs
      libyaml
    ];

    systemPath = [
      # local executables
      "$PATH:$HOME/.local/bin"
      # android studio
      "$PATH:$ANDROID_HOME/emulator"
      "$PATH:$ANDROID_HOME/platform-tools"
    ];

    variables = {
      ANDROID_HOME = "$HOME/Library/Android/sdk";
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
      inherit type user ai;
    };
  };

  # launch raycast on login
  launchd.user.agents.raycast.serviceConfig = {
    Disabled = false;
    ProgramArguments = [
      "${pkgs.raycast}/Contents/Library/LoginItems/RaycastLauncher.app/Contents/MacOS/RaycastLauncher"
    ];
    RunAtLoad = true;
  };

  # enable touch id for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # macos preferences
  imports = [
    ./macos/control-center.nix
    ./macos/desktop.nix
    ./macos/finder.nix
    ./macos/keyboard.nix
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
