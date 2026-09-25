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

  permissions = builtins.fromJSON (builtins.readFile "${ai}/rules/rules.json") // {
    defaultMode = "auto";
  };

  # Managed keys. `model` is deliberately absent: the app owns the model choice.
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    switchModelsOnFlag = false;
    autoMemoryEnabled = false;
    # Built-in style: result first, no narration, short by default; full detail on request.
    outputStyle = "Concise";
    # Less on screen: focus view hides tool-call noise; no turn timer. Focus view
    # needs the fullscreen renderer, which is otherwise picked by a server-side gate.
    tui = "fullscreen";
    viewMode = "focus";
    showTurnDuration = false;
    # Native completion/permission notifications: OSC 9, which WezTerm shows as a macOS notification.
    preferredNotifChannel = "iterm2";
    # Claude-specific environment configuration belongs in settings.json.
    env = {
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      # Pin the aliases subagents pass (pstack's model table uses them): a bare
      # `opus` can otherwise resolve to the older claude-opus-5.
      ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-5-5";
      ANTHROPIC_DEFAULT_FABLE_MODEL = "claude-fable-5-1";
    };
    attribution = {
      commit = "";
      pr = "";
    };
    # Permission rules from ai submodule.
    inherit permissions;
    autoMode.classifyAllShell = true;
    # The only hook: keeps pstack's poteto-mode on across turns. It adds context
    # and never blocks a prompt or a command.
    hooks.UserPromptSubmit = [
      {
        hooks = [
          {
            type = "command";
            command = "${config.ai.pstackModeHook}";
            timeout = 5;
          }
        ];
      }
    ];
    sandbox = {
      enabled = true;
      excludedCommands = [ "git" ];
      network = {
        allowLocalBinding = true;
        allowedDomains = import ../agent-network-domains.nix;
      };
    };
  };
  claudeSettingsFile = pkgs.writeText "claude-code-settings.json" (builtins.toJSON claudeSettings);
in
{
  # Claude Code symlinks (read-only, from ai submodule)
  home.file.".claude/CLAUDE.md".text =
    config.ai.instructions + builtins.readFile "${ai}/pstack/for-claude.md";
  home.file.".claude/skills".source = "${ai}/skills";
  home.file.".claude/agents".source = "${ai}/agents/claude";

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
        | (.[0] * $managed) | .hooks = $managed.hooks | .env = $managed.env' "$settings" "${claudeSettingsFile}" > "$tmp"
    else
      cp "${claudeSettingsFile}" "$tmp"
    fi
    mv "$tmp" "$settings"
  '';
}
