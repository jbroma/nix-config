{
  config,
  lib,
  pkgs,
  sandbox,
  llm,
  ...
}:
let
  proxyConfig = pkgs.writeText "agent-sandbox-squid.conf" ''
    http_port ${toString sandbox.proxyPort}
    visible_hostname agent-sandbox
    pid_filename none
    access_log none
    cache_log /dev/stderr
    cache_store_log none
    cache deny all
    cache_mem 0 MB
    pinger_enable off
    shutdown_lifetime 0 seconds
    acl sandbox src ${sandbox.subnets.internet}
    acl permitted_ports port 80 443
    acl tls_ports port 443
    acl non_public dst 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    acl non_public dst ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 2001:db8::/32
    http_access deny !sandbox
    http_access deny !permitted_ports
    http_access deny CONNECT !tls_ports
    http_access deny non_public
    http_access allow sandbox
    http_access deny all
  '';
in
lib.mkIf sandbox.enable {
  home.packages = [
    pkgs.agent-sandbox
    pkgs.apple-container
  ];
  home.file.".config/agent-sandbox/config.json".text = builtins.toJSON {
    stateDir = "${config.home.homeDirectory}/.local/state/agent-sandbox";
    container = "${pkgs.apple-container}/bin/container";
    context = "${../containers/agent-sandbox}";
    firewallCheck = "/run/current-system/sw/bin/agent-sandbox-check";
    inherit (sandbox) networks proxyPort;
    modelPort = if llm.server then llm.port else null;
    transferLimit = 512 * 1024 * 1024;
  };
  home.file.".local/state/agent-sandbox/.keep".text = "";
  launchd.agents.agent-sandbox-guard = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.agent-sandbox}/bin/agent-sandbox"
        "guard"
      ];
      RunAtLoad = true;
      StartInterval = 5;
      ThrottleInterval = 5;
      StandardOutPath = "${config.home.homeDirectory}/.local/state/agent-sandbox/guard.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/state/agent-sandbox/guard.log";
    };
  };
  launchd.agents.agent-sandbox-proxy = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/opt/squid/sbin/squid"
        "-N"
        "-f"
        "${proxyConfig}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      StandardOutPath = "${config.home.homeDirectory}/.local/state/agent-sandbox/proxy.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/state/agent-sandbox/proxy.log";
    };
  };
}
