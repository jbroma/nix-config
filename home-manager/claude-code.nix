{
  pkgs,
  lib,
  ai,
  config,
  ...
}:

let
  # MCP servers: wrap in mcpServers key for Claude Code format
  mcpServersConfig = {
    mcpServers = config.mcp.servers;
  };
  mcpServersJson = builtins.toJSON mcpServersConfig;

  permissions = builtins.fromJSON (builtins.readFile "${ai}/rules/rules.json");

  # Managed keys. `model` is deliberately absent: the app owns the model choice.
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    switchModelsOnFlag = false;
    # Keep extended thinking enabled.
    alwaysThinkingEnabled = true;
    # Built-in style: result first, no narration, short by default; full detail on request.
    outputStyle = "Concise";
    # Less on screen: focus view hides tool-call noise; no thinking summaries or turn timer.
    viewMode = "focus";
    showThinkingSummaries = false;
    showTurnDuration = false;
    # Native completion/permission notifications: OSC 9, which WezTerm shows as a macOS notification.
    preferredNotifChannel = "iterm2";
    # Claude-specific environment configuration belongs in settings.json.
    env = {
      DISABLE_AUTOUPDATER = "1";
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      ENABLE_TOOL_SEARCH = "true";
    };
    attribution = {
      commit = "";
      pr = "";
    };
    # Permission rules from ai submodule.
    inherit permissions;
    hooks = config.ai.hooks;
    sandbox = {
      enabled = true;
      excludedCommands = [ "git" ];
      autoAllowBashIfSandboxed = true;
      network = {
        allowLocalBinding = true;
      };
    };
  };
  claudeSettingsFile = pkgs.writeText "claude-code-settings.json" (builtins.toJSON claudeSettings);
in
{
  # Claude Code symlinks (read-only, from ai submodule)
  home.file.".claude/CLAUDE.md".text = config.ai.instructions;
  home.file.".claude/skills".source = "${ai}/skills";
  home.file.".claude/agents".source = "${ai}/agents/claude";

  # dcg (PreToolUse Bash hook) reads its packs and policy from here.
  xdg.configFile."dcg/config.toml".source = "${ai}/hooks/dcg.toml";

  # Binary symlink for ~/.local/bin (needed by claude code native install)
  home.file.".local/bin/claude".source = "${pkgs.claude-code}/bin/claude";

  # MCP servers: merge into ~/.claude.json (preserves OAuth, preferences, stats)
  home.activation.setupMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${../scripts/merge-mcp-servers.sh} \
      "${config.home.homeDirectory}/.claude.json" \
      "${pkgs.writeText "mcp-servers.json" mcpServersJson}" \
      "${config.mcp.secretsFile}" \
      "${pkgs.jq}/bin/jq"
  '';

  # Claude mutates settings.json, so keep it writable while refreshing managed keys.
  # Objects deep-merge, which would keep removed hook events and env vars alive,
  # so the fully-managed `hooks` and `env` objects are replaced wholesale.
  home.activation.setupClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${config.home.homeDirectory}/.claude/settings.json"
    tmp="$settings.tmp"

    mkdir -p "${config.home.homeDirectory}/.claude"
    if [ -e "$settings" ] || [ -L "$settings" ]; then
      "${pkgs.jq}/bin/jq" -s '.[1] as $managed
        | del(.[0].extraKnownMarketplaces["ai-sauce"])
        | (.[0] * $managed) | .hooks = $managed.hooks | .env = $managed.env' "$settings" "${claudeSettingsFile}" > "$tmp"
    else
      cp "${claudeSettingsFile}" "$tmp"
    fi
    mv "$tmp" "$settings"
  '';

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
  };
}
