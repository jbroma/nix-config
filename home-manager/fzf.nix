{
  pkgs,
  lib,
  ...
}:
let
  fd = lib.getExe pkgs.fd;
in
{
  programs.fzf = rec {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "${fd} -H --type f";
    defaultOptions = [ "--height 50%" ];
    fileWidget = {
      command = "${defaultCommand}";
      options = [
        "--preview '${lib.getExe pkgs.bat} --color=always --plain --line-range=:200 {}'"
      ];
    };
    changeDirWidget = {
      command = "${fd} -H --type d";
      options = [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
    };
    historyWidget.options = [ ];
  };
}
