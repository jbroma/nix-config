{ 
  config, 
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
  ];

  # List packages you want to install system-wide.
  environment.systemPackages = with pkgs; [
    # xcode
    google-chrome
    code-cursor
    _1password-gui
    git
    vim
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ./home.nix;
    extraSpecialArgs = {
      inherit type;
    };
  };

  system.defaults = {
    dock = {
      autohide = true;
    };
  };

  system.primaryUser = username;

  system.stateVersion = 4;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
}
