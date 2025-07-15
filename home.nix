{ 
  config, 
  pkgs,
  type,
  ... 
}: 

{
  # List packages you want to install for your user only.
  home.packages = with pkgs; [
    htop
  ];

  home.stateVersion = "25.11";

  programs.git = {
    enable = true;
    userName = "Jakub Romanczyk";
    userEmail =
      if type == "work" then
        "jakub.romanczyk@callstack.com"
      else
        "j.romanczyk@gmail.com";
    extraConfig = {
      core.editor = "vim";
      push.autoSetupRemote = true;
      push.default = "simple";
      url."ssh://git@github.com/".insteadof="https://github.com/";
      url."https://".insteadof="git://";
    };
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      darwin-rebuild-switch = "sudo ~/.nix/rebuild-and-switch.sh";
      code = "cursor";
      ll = "ls -l";
    };
  };

  imports = [
    ./home-manager/1password.nix
  ];
}