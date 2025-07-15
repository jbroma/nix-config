{
  config,
  lib,
  pkgs,
  type,
  ...
}:

{
  programs.git = {
    enable = true;
    userName = "Jakub Romanczyk";
    userEmail =
      if type == "work" then "jakub.romanczyk@callstack.com"
      else "j.romanczyk@gmail.com";
    extraConfig = {
      core.editor = "vim";
      push.autoSetupRemote = true;
      push.default = "simple";
      url."ssh://git@github.com/".insteadof="https://github.com/";
      url."https://".insteadof="git://";
    };
  };
}