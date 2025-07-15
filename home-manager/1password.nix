{
  config,
  lib,
  pkgs,
  type,
  ...
}: let
  home = config.home.homeDirectory;
  agentPath = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  signPath = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  sockLink = ".1password/agent.sock";
  sockPath = "${home}/${sockLink}";

  signingKey = if type == "work" then "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+aLyPSbvGQTUA/UQDMsNJFsek1uJ/Qwqv/1j/fOuqGx1ZOnYON3oeQk5VWQl+gyGzF0TDmwgtIfmgfE0eqSBMaif+qnZ/X+zJV0ck/leWHBnIjM4Zwj47JFPNEFCuiypyF1KJITyQl6tgfHAD0TQmMJBJHqtVu7BJEk5ZGJuuDEGpZ/1vTS+kLCWCMOgO61bv+4T9Fy/AFS599JhX5KGisX+VtoOz4jmC1c4yUueqkcFoDnVuIVD/dLCEQ1/hd9Z1m55zAdRULuYj2f/KBHp54h/b2iN5XYbjS36vvEs4MfEnJpwx66d/YmsnPMWxrL7AZGfPHGVpoQpWX5lcs3U3gEY81s303Q0+vZd5ar3zH8QbDg+kO26fLqfGUgCKGDtUqhfepR63OID8Z/Gg64igAwnS//Db9Ds3+vbbJPswHpMjNdh0+P18h/qBkIe9om67/N+b4j9mSozBz97INN5tYts3EwaEgTcaRkuQPvQVkRF3lizAKxacbmDpGM9Sues=" 
               else null;
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
    signing = {
      signByDefault = true;
      key = null;
      signer = signPath;
    };
    extraConfig = {
      gpg.format = "ssh";
      user.signingKey = signingKey;
    };
  };
}