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
    userEmail = if type == "work" then "jakub.romanczyk@callstack.com" else "j.romanczyk@gmail.com";
    extraConfig = {
      alias = {
        s = "status";
        l = "log";
        d = "diff";
        dc = "diff --cached";
        a = "add";
        c = "commit";
        ca = "commit --amend";
        cn = "commit --amend --no-edit";
        ch = "checkout";
        cp = "cherry-pick";
        sw = "switch";
        pushf = "push --force-with-lease";
        publish = "!git push -u origin $(git rev-parse --abbrev-ref HEAD)";
        r1 = "rebase HEAD^ -i";
        r2 = "rebase HEAD~2 -i";
        r3 = "rebase HEAD~3 -i";
        r4 = "rebase HEAD~4 -i";
        r5 = "rebase HEAD~5 -i";
        dt = "difftool --tool=vimdiff -y";
        dtc = "dt --cached -y";
      };
      core.editor = "vim";
      init.defaultBranch = "main";
      merge.conflictstyle = "zdiff3";
      push.autoSetupRemote = true;
      push.default = "simple";
      url."ssh://git@github.com/".insteadof = "https://github.com/";
      url."https://".insteadof = "git://";
    };
  };
}
