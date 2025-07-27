{
  lib,
  pkgs,
  type,
  ...
}:

let
  username = "jbroma";
in
{
  # use Determinate Nix daemon
  nix.enable = false;

  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-users = [
      "root"
      username
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
      "Xcode.app"
      "google-chrome"
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
      xcode
      android-studio
      google-chrome
      cursor
      raycast
      minisim
      discord
      spotify
      _1password-gui
      git
      ghostty
      oh-my-posh
      sketchybar
      nerd-fonts.fira-code
      nixfmt-rfc-style
      vim
      # libs
      libyaml
    ];

    systemPath = [
      "$PATH:$ANDROID_HOME/emulator"
      "$PATH:$ANDROID_HOME/platform-tools"
    ];

    variables = {
      ANDROID_HOME = "$HOME/Library/Android/sdk";
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ./home.nix;
    extraSpecialArgs = {
      inherit type;
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

  system.primaryUser = username;

  system.stateVersion = 4;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # install xcode command line tools if not installed
  system.activationScripts.preActivation.text = ''
    if ! xcode-select --version 2>/dev/null; then
      xcode-select --install
    fi
  '';
}
