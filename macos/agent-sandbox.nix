# Shared agent sandbox policy. Each profile has its own source range and gateway allowlist.
{
  lib,
  pkgs,
  llm,
  sandbox,
  user,
  ...
}:

let
  # The wildcard evaluates children alphabetically. Run before Apple's service anchors;
  # agent-sandbox-check refuses startup if another anchor precedes this one.
  anchor = "com.apple/000.agent-sandbox";
  clients = lib.concatStringsSep ", " llm.clients;
  port = toString llm.port;
  gateways =
    profile: lib.concatMapStringsSep ", " (network: network.gateway) sandbox.networks.${profile};
  rules = pkgs.writeText "agent-sandbox.pf" ''
    table <llm_clients> { ${clients} }
    pass in quick inet proto tcp from ${sandbox.subnets.internet} to { ${gateways "internet"} } port ${toString sandbox.proxyPort}
    ${lib.optionalString llm.server ''
      pass in quick inet proto tcp from ${sandbox.subnets.model} to { ${gateways "model"} } port ${port}
    ''}
    block drop in quick inet from { ${lib.concatStringsSep ", " (lib.attrValues sandbox.subnets)} } to any
    block drop in quick proto tcp to any port ${toString sandbox.proxyPort}
    ${lib.optionalString llm.server ''
      pass in quick on lo0 proto tcp to any port ${port}
      pass in quick inet proto tcp from <llm_clients> to any port ${port}
      block drop in quick proto tcp from any to any port ${port}
    ''}
  '';
  snapshot = "/var/run/agent-sandbox-pf.rules";
  check = pkgs.writeShellApplication {
    name = "agent-sandbox-check";
    runtimeInputs = [ pkgs.gnugrep ];
    runtimeEnv = {
      PF_RULES = rules;
      PF_ANCHOR = anchor;
      PF_SNAPSHOT = snapshot;
    };
    text = builtins.readFile ../scripts/agent-sandbox-check.sh;
  };
in
lib.mkIf sandbox.enable {
  homebrew.brews = [ "squid" ];
  environment.systemPackages = [ check ];
  # The sole passwordless operation reads pf state. No arguments, rule loading or enabling.
  security.sudo.extraConfig = ''
    ${user.username} ALL=(root) NOPASSWD: /run/current-system/sw/bin/agent-sandbox-check ""
  '';
  # `script` runs under nix-darwin's wait4path wrapper (no race with the /nix volume mount) as a
  # real shell script, so both steps run (`command` would exec the first one). -E takes a pf
  # reference so other components releasing theirs cannot disable pf underneath.
  launchd.daemons.agent-sandbox-pf = {
    script = ''
      set -euo pipefail
      /sbin/pfctl -q -a ${anchor} -f ${rules}
      active=$(/sbin/pfctl -a ${anchor} -sr)
      test -n "$active"
      # Root-owned, atomic snapshot of the rules just loaded, tied to this configuration.
      # Write it before -E so a filesystem failure cannot leak enable references on retries.
      umask 077
      tmp=$(/usr/bin/mktemp /var/run/agent-sandbox-pf.XXXXXX)
      trap '/bin/rm -f "$tmp"' EXIT
      printf '%s\n%s\n' ${rules} "$active" > "$tmp"
      /bin/mv "$tmp" ${snapshot}
      /sbin/pfctl -q -E
    '';
    serviceConfig = {
      RunAtLoad = true;
      # Retry failed loads/enables, but stop after success so -E takes only one reference.
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 30;
      StandardErrorPath = "/var/log/agent-sandbox-pf.log";
      StandardOutPath = "/var/log/agent-sandbox-pf.log";
    };
  };
}
