{ ... }:
{
  programs.t3code = {
    enable = true;
    # The app is the t3-code@nightly cask (configuration.nix): nightly builds follow the
    # nightly update feed by default, and the app's own updater replaces them.
    package = null;
    userSettings = {
      enableDeviceSupport = true;
      enableAgentDeviceAccess = true;
      # "Auto" in the UI: providers that support it approve routine actions; others still ask.
      defaultRuntimeMode = "auto";
      continueThreadsAfterServerUpdate = true;
      snoozeLimitedThreads = true;
      autoResumeLimitedThreads = true;
      storageCleanup = {
        worktreeOnDelete = true;
        worktreeAfterDays = 30;
        logsAfterDays = 14;
      };
      # An instance replaces the legacy providers.<kind> entry, so settings go here.
      # T3 reads PATH from a login shell with a 5 s timeout and `zsh -il` takes ~3.5 s,
      # so pin the Homebrew CLIs. Cursor runs the SDK bundled in the app.
      providerInstances = {
        claudeAgent = {
          driver = "claudeAgent";
          config.binaryPath = "/opt/homebrew/bin/claude";
        };
        codex = {
          driver = "codex";
          config.binaryPath = "/opt/homebrew/bin/codex";
        };
        cursor = {
          driver = "cursor";
          enabled = true;
        };
      };
    };
    clientSettings.sidebarWorkingShelfEnabled = true;
  };
}
