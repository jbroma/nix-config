{
  config,
  type,
  ...
}:
let
  home = config.home.homeDirectory;
  agentPath = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  signPath = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  sockLink = ".1password/agent.sock";
  sockPath = "${home}/${sockLink}";

  signingKey =
    if type == "work" then
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+aLyPSbvGQTUA/UQDMsNJFsek1uJ/Qwqv/1j/fOuqGx1ZOnYON3oeQk5VWQl+gyGzF0TDmwgtIfmgfE0eqSBMaif+qnZ/X+zJV0ck/leWHBnIjM4Zwj47JFPNEFCuiypyF1KJITyQl6tgfHAD0TQmMJBJHqtVu7BJEk5ZGJuuDEGpZ/1vTS+kLCWCMOgO61bv+4T9Fy/AFS599JhX5KGisX+VtoOz4jmC1c4yUueqkcFoDnVuIVD/dLCEQ1/hd9Z1m55zAdRULuYj2f/KBHp54h/b2iN5XYbjS36vvEs4MfEnJpwx66d/YmsnPMWxrL7AZGfPHGVpoQpWX5lcs3U3gEY81s303Q0+vZd5ar3zH8QbDg+kO26fLqfGUgCKGDtUqhfepR63OID8Z/Gg64igAwnS//Db9Ds3+vbbJPswHpMjNdh0+P18h/qBkIe9om67/N+b4j9mSozBz97INN5tYts3EwaEgTcaRkuQPvQVkRF3lizAKxacbmDpGM9Sues="
    else if type == "personal" then
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDK4vfA0oF8MtZm9A/bAYR3NWzTf81aUUGFI3wbLVT0dyfTXE5sMeJ1ednO2dQ8bpoFV2h6WeY/9LjkzdGeO2NbiN4c8pJ4YzPW5XSBzNYXG+7dXVBSyXVfznl/RAl2E9KrbMiexP1eMPgP4VM7X8feSbewR08H4WtrWMeht26C9qX/5QHb/HRXykfNykIZVMXZ5uJJmI+U3mQdSCPf1Z8x7cj0zFCl4X4XD/EigvKoi6FzvXEZVMRoeAIIYbPHmRQMSZkiUzYffINBxGv5QwxAL2VmuwiGv0vU7RGPFNdZVjg8XQ9ph6g+B0R4xcr6f6erUz0s59gkojhpImiAT9iLNGS50TTLSjeBPavVSZEtAoArRHHKm7+bL34PS3N9p/tdELgBAUd3o9sz2Luou2p290AZOiROW48DwMH+2+TiP0YybqWAUYkRudIuP8KZqizw2RiE2kBXJloNQimAXfhNJDKQZRRwyOn0/GOzSI302z60auzPXiSlC9SOIrmo/h+ooqkzMpuZPd30htQzf1QNEmG4gGCngJ0eTfWgmOc7K6n3j6pBHSkI7HPBzA6u6m4iR+afdDPI6pwLlfb/zDBi+xkIas1rdLy0e07VItoSECoNYs+tk1cvHZ4o7Vvx7jHBnMrcAQZlbRnpe3KkUhfEiAnAMJPDmdSsEY2ZmZhXew=="
    else
      null;
in
{
  home.sessionVariables = {
    SSH_AUTH_SOCK = sockPath;
  };

  home.file.sock = {
    source = config.lib.file.mkOutOfStoreSymlink agentPath;
    target = sockLink;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

  programs.git = {
    signing = {
      signByDefault = true;
      key = null;
      signer = signPath;
    };
    settings = {
      gpg.format = "ssh";
      user.signingKey = signingKey;
    };
  };
}
