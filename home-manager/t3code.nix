{ lib, pkgs, ... }:
{
  programs.t3code = {
    enable = true;
    # The app is the Homebrew cask (configuration.nix) so its own updater can replace it.
    package = null;
    # The GUI doesn't see the shell PATH, so point it at the Nix-managed CLIs.
    userSettings = {
      # This switch also gates T3's hourly model list fetch, so off means no new models
      # until the next app release. Explicit because activation merges into the old false.
      enableProviderUpdateChecks = true;
      providers = {
        claudeAgent.binaryPath = lib.getExe pkgs.claude-code;
        codex.binaryPath = lib.getExe pkgs.codex-cli;
      };
    };
  };
}
