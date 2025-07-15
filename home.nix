{ 
  config, 
  pkgs,
  type ? "personal",
  ... 
}: let
  onePassSockPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in {
  # List packages you want to install for your user only.
  home.packages = with pkgs; [
    htop
  ];

  home.stateVersion = "25.11";

  # 1password ssh agent
  home.sessionVariables = {
    SSH_AUTH_SOCK = onePassSockPath;
  };

  programs.ssh = {
    enable = true;
  };

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
      darwin-rebuild-switch = "~/.nix/rebuild-and-switch.sh";
      code = "cursor";
      ll = "ls -l";
    };
  };
}