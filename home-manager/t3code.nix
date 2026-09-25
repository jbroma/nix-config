{ lib, pkgs, ... }:
{
  # Follow the nightly update feed: the app's own updater swaps in nightly builds.
  # The app rewrites desktop-settings.json (window bounds), so merge the key in on switch.
  home.activation.t3codeDesktopSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${../scripts/merge-cursor-settings.sh} \
      "$HOME/.t3/userdata/desktop-settings.json" \
      "${
        pkgs.writeText "t3code-desktop-settings.json" (
          builtins.toJSON {
            updateChannel = "nightly";
            updateChannelConfiguredByUser = true;
          }
        )
      }" \
      "${pkgs.jq}/bin/jq"
  '';

  programs.t3code = {
    enable = true;
    # The app is the Homebrew cask (configuration.nix) so its own updater can replace it.
    package = null;
    # The GUI doesn't see the shell PATH, so point it at the Homebrew CLIs.
    userSettings = {
      # This switch also gates T3's hourly model list fetch, so off means no new models
      # until the next app release. Explicit because activation merges into the old false.
      enableProviderUpdateChecks = true;
      enableDeviceSupport = true;
      # Off until pingdotgg/t3code#12926 is fixed: the agent-device shim launches a
      # second T3 instance, which marks live sessions lost and breaks Cmd+Tab.
      enableAgentDeviceAccess = false;
      # "Auto" in the UI: providers that support it approve routine actions; others still ask.
      defaultRuntimeMode = "auto";
      providers = {
        claudeAgent.binaryPath = "/opt/homebrew/bin/claude";
        codex.binaryPath = "/opt/homebrew/bin/codex";
        cursor = {
          enabled = true;
          binaryPath = "/opt/homebrew/bin/cursor-agent";
        };
      };
    };
  };
}
