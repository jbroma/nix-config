# Development subset of https://learn.chatgpt.com/docs/cloud/internet-access
# plus the Nix caches and Claude distribution host used by this configuration.
# Shared by Claude sandbox.network.allowedDomains and Codex network_proxy.domains.
[
  "github.com"
  "*.github.com"
  "*.githubusercontent.com"
  "registry.npmjs.org"
  "nodejs.org"
  "pypi.org"
  "files.pythonhosted.org"
  "cache.nixos.org"
  "cache.flakehub.com"
  "install.determinate.systems"
  "storage.googleapis.com"
]
