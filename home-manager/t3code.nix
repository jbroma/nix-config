_:
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
