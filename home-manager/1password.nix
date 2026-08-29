{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  home = config.home.homeDirectory;
  agentPath = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  signPath = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  sockLink = ".1password/agent.sock";
  sockPath = "${home}/${sockLink}";

  signingKeys = import ../ssh-keys.nix;

  signingKey = signingKeys.${user.email} or null;

  # Lets git verify our own SSH signatures (git log --show-signature, %G?).
  allowedSigners = pkgs.writeText "allowed_signers" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList (email: key: "${email} ${key}") signingKeys)
  );
in
{
  home.sessionVariables = {
    SSH_AUTH_SOCK = sockPath;
  };

  home.file.sock = {
    source = config.lib.file.mkOutOfStoreSymlink agentPath;
    target = sockLink;
  };

  # IdentityAgent covers clients that never see SSH_AUTH_SOCK (git in Cursor, Zed).
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".IdentityAgent = sockPath;
  };

  programs.git = {
    signing = {
      signByDefault = signingKey != null;
      key = signingKey;
      signer = signPath;
    };
    settings = {
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "${allowedSigners}";
    };
  };
}
