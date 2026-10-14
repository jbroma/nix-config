# T3 Code's Network access listens on every interface. Only the CIDRs in user.nix `t3Clients`
# (home LAN, WireGuard peers) may reach it; any other network, such as public Wi-Fi, is dropped.
{
  lib,
  pkgs,
  user,
  ...
}:

let
  clients = user.t3Clients or [ ];
  # Sorts after agent-sandbox's 000 anchor, which must stay first.
  anchor = "com.apple/010.t3-code";
  port = "3773";
  rules = pkgs.writeText "t3-code.pf" ''
    pass in quick on lo0 proto tcp to any port ${port}
    pass in quick inet proto tcp from { ${lib.concatStringsSep ", " clients} } to any port ${port}
    block drop in quick proto tcp to any port ${port}
  '';
in
lib.mkIf (clients != [ ]) {
  # Same loader as agent-sandbox-pf: retry until the anchor loads, then take one pf reference.
  launchd.daemons.t3-code-pf = {
    script = ''
      set -euo pipefail
      /sbin/pfctl -q -a ${anchor} -f ${rules}
      test -n "$(/sbin/pfctl -a ${anchor} -sr)"
      /sbin/pfctl -q -E
    '';
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 30;
      StandardErrorPath = "/var/log/t3-code-pf.log";
      StandardOutPath = "/var/log/t3-code-pf.log";
    };
  };
}
