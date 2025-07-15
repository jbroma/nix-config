{
  config,
  lib,
  pkgs,
  ...
}: let
  home = config.home.homeDirectory;
  agentPath = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  signPath = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  sockLink = ".1password/agent.sock";
  sockPath = "${home}/${sockLink}";
in {
  home.sessionVariables = {
    SSH_AUTH_SOCK = sockPath;
  };

  home.file.sock = {
    source = config.lib.file.mkOutOfStoreSymlink agentPath;
    target = sockLink;
  };

  programs.ssh = {
    enable = true;
  };

  programs.git = {
    commit = {
      gpgsign = true;
    };
    signing = {
      signByDefault = true;
      key = null;
      signer = signPath;
    };
    extraConfig = {
      gpg.format = "ssh";
    };
  };
}