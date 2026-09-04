# pf policy on the LLM server (llm from flake.nix). Vault note: Homelab/LLM Server.md
# - The pi-sandbox harness runs on a host-only container network, so LAN and internet are out of
#   reach by construction; pf limits host access to the proxy's port.
# - The proxy also checks llm.clients and restricts the sandbox to chat completions.
#   Raw Ollama listens only on loopback. See home-manager/llm.nix.
# Loaded at every boot (pf anchors do not persist); nothing toggles it at run time.
{
  lib,
  pkgs,
  llm,
  user,
  ...
}:

let
  # The wildcard evaluates children alphabetically. Run before Apple's service anchors;
  # llm-sandbox-check refuses startup if another anchor precedes this one.
  anchor = "com.apple/000.llm-sandbox";
  clients = lib.concatStringsSep ", " llm.clients;
  port = toString llm.port;
  # No interface names: vmnet numbers bridges by creation order and sometimes uses none at all.
  # pi-sandbox disables guest IPv6 and raw packets. The proxy port rule also covers IPv6
  # on the host, where localhost may resolve to ::1.
  rules = pkgs.writeText "llm-sandbox.pf" ''
    table <llm_clients> { ${clients} }
    pass in quick on lo0 proto tcp to any port ${port}
    pass in quick inet proto tcp from ${llm.sandboxSubnet} to any port ${port}
    block drop in quick inet from ${llm.sandboxSubnet} to any
    pass in quick inet proto tcp from <llm_clients> to any port ${port}
    block drop in quick proto tcp from any to any port ${port}
  '';
  snapshot = "/var/run/llm-sandbox-pf.rules";
  check = pkgs.writeShellApplication {
    name = "llm-sandbox-check";
    runtimeInputs = [ pkgs.gnugrep ];
    runtimeEnv = {
      PF_RULES = rules;
      PF_ANCHOR = anchor;
      PF_SNAPSHOT = snapshot;
    };
    text = builtins.readFile ../scripts/llm-sandbox-check.sh;
  };
in
lib.mkIf llm.server {
  environment.systemPackages = [ check ];
  # The sole passwordless operation reads pf state. No arguments, rule loading or enabling.
  security.sudo.extraConfig = ''
    ${user.username} ALL=(root) NOPASSWD: /run/current-system/sw/bin/llm-sandbox-check ""
  '';
  # `script` runs under nix-darwin's wait4path wrapper (no race with the /nix volume mount) as a
  # real shell script, so both steps run (`command` would exec the first one). -E takes a pf
  # reference so other components releasing theirs cannot disable pf underneath.
  launchd.daemons.llm-sandbox-pf = {
    script = ''
      set -euo pipefail
      /sbin/pfctl -q -a ${anchor} -f ${rules}
      active=$(/sbin/pfctl -a ${anchor} -sr)
      test -n "$active"
      # Root-owned, atomic snapshot of the rules just loaded, tied to this configuration.
      # Write it before -E so a filesystem failure cannot leak enable references on retries.
      umask 077
      tmp=$(/usr/bin/mktemp /var/run/llm-sandbox-pf.XXXXXX)
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
      StandardErrorPath = "/var/log/llm-sandbox-pf.log";
      StandardOutPath = "/var/log/llm-sandbox-pf.log";
    };
  };
}
