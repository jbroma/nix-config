{ 
  config, 
  pkgs,
  type ? "personal",
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
    signing = {
      key = "93C4B07A21F540D0";
      signByDefault = true;
    };
    extraConfig = {
      core.editor = "vim";
      push.autoSetupRemote = true;
      push.default = "simple";
      gpg.program = "gpg";
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