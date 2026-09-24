{ lib, pkgs, ... }:
{
  programs.t3code = {
    enable = true;
    # The app is the Homebrew cask (configuration.nix) so its own updater can replace it.
    package = null;
    # The GUI doesn't see the shell PATH, so point it at the Nix-managed CLIs.
    # Nix updates them, so T3's own update checks only nag.
    userSettings = {
      enableProviderUpdateChecks = false;
      providers = {
        claudeAgent.binaryPath = lib.getExe pkgs.claude-code;
        codex.binaryPath = lib.getExe pkgs.codex-cli;
      };
    };
  };
}
