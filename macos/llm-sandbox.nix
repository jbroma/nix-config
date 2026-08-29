# pf policy on the LLM server (llm from flake.nix). Vault note: Homelab/LLM Server.md
# - The pi-sandbox harness runs on a host-only container network, so LAN and internet are out of
#   reach by construction; pf limits what it may reach on the host itself to Ollama's port.
# - Ollama's unauthenticated API (0.0.0.0:11434) accepts only llm.clients, the sandbox and loopback.
# Loaded at every boot (pf anchors do not persist); nothing toggles it at run time.
{
  lib,
  pkgs,
  llm,
  ...
}:

let
  anchor = "com.apple/llm-sandbox"; # sub-anchor of com.apple/*, which /etc/pf.conf already evaluates
  clients = lib.concatStringsSep ", " llm.clients;
  port = toString llm.port;
  # No interface names: vmnet numbers bridges by creation order and sometimes uses none at all.
  # Rules without an address family cover IPv6 too (Ollama's wildcard listener is dual-stack,
  # and localhost resolves to ::1 first for some clients).
  rules = pkgs.writeText "llm-sandbox.pf" ''
    table <llm_clients> { ${clients} }
    pass in quick on lo0 proto tcp to any port ${port}
    pass in quick inet proto tcp from ${llm.sandboxSubnet} to any port ${port}
    block drop in quick inet from ${llm.sandboxSubnet} to any
    pass in quick inet proto tcp from <llm_clients> to any port ${port}
    block drop in quick proto tcp from any to any port ${port}
  '';
in
lib.mkIf llm.server {
  # `script` runs under nix-darwin's wait4path wrapper (no race with the /nix volume mount) as a
  # real shell script, so both steps run (`command` would exec the first one). -E takes a pf
  # reference so other components releasing theirs cannot disable pf underneath.
  launchd.daemons.llm-sandbox-pf = {
    script = ''
      /sbin/pfctl -q -a ${anchor} -f ${rules}
      /sbin/pfctl -q -E
    '';
    serviceConfig = {
      RunAtLoad = true;
      StandardErrorPath = "/var/log/llm-sandbox-pf.log";
      StandardOutPath = "/var/log/llm-sandbox-pf.log";
    };
  };
}
