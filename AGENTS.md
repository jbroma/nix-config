# AGENTS.md

This file provides guidance to AI coding assistants when working with code in this repository.

## Repository Purpose

Personal macOS configuration using Nix Flakes, nix-darwin, and home-manager: dotfiles, tools, and the machine roles that live with them (the local-LLM server and its sandboxed harness under `macos/llm-*.nix`, `home-manager/llm.nix`, `containers/`). Project development environments themselves still use Docker Compose, not this repo.

## Commands

```bash
# Primary workflow
mise run check-personal      # Build the personal config without applying
mise run check-work          # Build the work config without applying
mise run check-llm-server    # Build with the LLM server role forced on (server-only code never evaluates otherwise)
mise run check-agent-sandbox # Build the standalone sandbox role and run harmless fixture tests
mise run update              # Update flake inputs

# Manual shell aliases (human use only; agents must not apply config)
darwin-rebuild-switch        # Rebuild and apply darwin configuration
darwin-cleanup               # Prune generations older than 7 days
flake-update                 # Same as mise run update

```

## Architecture

```
flake.nix                    # Entry point - two configs: work, personal
├── configuration.nix        # System-level (nix-darwin): packages, services, security
├── home.nix                 # User-level entry: imports home-manager modules
├── user.nix                 # User identity (git skip-worktree, not committed)
├── ssh-keys.nix             # Public keys per identity: git signing keys and LLM-server authorized keys
│
├── home-manager/            # Home-manager modules
│   ├── claude-code.nix      # Claude Code: settings, skills, agents
│   ├── codex.nix            # Codex: settings, skills, agents, rules
│   ├── cursor.nix           # Cursor: settings, extensions, MCP, skills
│   ├── zsh.nix              # Shell config with modern CLI aliases
│   └── [tool].nix           # Per-tool configurations
│
├── macos/                   # macOS system preferences and roles (llm-server, agent-sandbox pf policy)
├── pkgs/                    # Custom package derivations (auto-loaded by flake)
├── scripts/                 # Shell scripts packaged or run by modules (pi-sandbox launcher, helpers)
├── containers/              # Image build contexts (pi-sandbox: Dockerfile + entrypoint)
├── dotfiles/                # Non-Nix config files (sketchybar, oh-my-posh, vscode)
└── ai/                      # Nix flake input (ai-sauce) - skills, agents, rules
```

**Key patterns:**

- `specialArgs = { inherit type user ai llm; }` passes profile type (work/personal), user info, the private AI input and the local-LLM role (`llm.server`, `llm.host`, `llm.clients`, derived from `user.nix`) to all modules
- Custom packages in `./pkgs/` are auto-loaded via `mapAttrs'` over the directory
- Overlays substitute custom packages such as Claude Code and Codex CLI

## AI Integration

Generic Apple container sandboxes live in `scripts/agent-sandbox.py`, `home-manager/agent-sandbox.nix` and `macos/agent-sandbox.nix`. Pi is a consumer of that runner. See `docs/agent-sandbox.md` for the disposable workspace and export contract. Sandbox tests must use harmless fixtures, never destructive host-isolation probes.

The `ai/` directory is a Nix flake input providing shared configuration for AI coding tools. Each tool has its own home-manager module that symlinks relevant parts:

- `claude-code.nix`: `~/.claude/skills`, `~/.claude/agents`, `~/.claude/CLAUDE.md`
- `codex.nix`: `~/.codex/skills`, `~/.codex/agents`, `~/.codex/AGENTS.md`, `~/.codex/rules/default.rules`, generated `~/.codex/config.toml`
- `cursor.nix`: `~/.cursor/skills`, `~/.cursor/agents`, a local plugin `~/.cursor/plugins/local/ai-sauce` carrying CORE.md as an always-applied rule, generated `~/.cursor/mcp.json` and Cursor settings. Cursor keeps its own copies: the IDE toggle "Include third-party Plugins, Skills, and other configs" must stay off (activation warns otherwise)

pstack's skills are written for Cursor, so each tool also gets ai-sauce's per-tool pstack file. `claude-code.nix` and `codex.nix` append `pstack/for-claude.md` and `pstack/for-codex.md` to the generated `CLAUDE.md` and `AGENTS.md`. `cursor.nix` links `pstack/for-cursor.mdc` as the `pstack-models` rule. It renders Cursor agents from `agents/codex/*.toml`, except where ai-sauce ships the agent in Cursor's own format under `agents/cursor/`, which wins.

Claude Code and Codex have one hook, `ai.pstackModeHook` from `ai-instructions.nix`. It wraps ai-sauce's `pstack/mode-hook.sh` with its own PATH, because a hook inherits the tool's PATH and Nix's bash has no default one. It runs on `UserPromptSubmit` and keeps pstack's `poteto-mode` on across turns. Claude gets the store path in its settings. Codex gets `~/.codex/hooks.json` pointing at the stable `~/.codex/hooks/pstack-mode`, because Codex trusts a hook by the hash of its definition. After the first switch, trust it once through `/hooks` in Codex.

Cursor's permissions come from the same `rules/rules.json` Claude Code uses. `cursor.nix` turns the allow rules into `~/.cursor/permissions.json` (`terminalAllowlist`, `mcpAllowlist`). Cursor has no deny list, so `~/.cursor/hooks.json` runs a deny hook on `beforeShellExecution` and `beforeReadFile` for the deny rules. `~/.cursor/sandbox.json` takes its network allowlist from `agent-network-domains.nix`, like Claude's sandbox and Codex's network proxy. The run mode (Auto-review, Allowlist, Run Everything) and the sandbox network mode are UI-only in Cursor Settings > Agents.

MCP servers are declared once in `mcp-servers.nix`; API keys live in the macOS Keychain and are injected into the Claude Code, Codex, and Cursor configs at activation (`keychain-mcp sync` seeds them from 1Password).

Cursor's Agents Window reads project instructions from the active workspace, such as root `AGENTS.md` and `.cursor/rules/*.mdc`. Global personal rules are Cursor User Rules configured through Cursor Settings > Rules; home-level `~/.cursor/rules/*.mdc` files are not a reliable injected prompt source for the Agents Window.

The `ai` input is also symlinked to `~/.nix/ai` for visibility (in `home.nix`).

## Git Workflow

- Work directly on `main`; create a branch only when the user explicitly requests one.
- This repository is public. Never commit secrets, local `user.nix` values, or runtime audit output.
- Before committing, inspect recent history and match the existing subject style.
- Commit messages use `area: short summary`, such as `homebrew: move apps to Homebrew`; do not default to Conventional Commits (`chore:`, `fix:`, etc.) unless the local history has already moved to that style.
- Keep commits signed. If signing fails, retry with escalation rather than bypassing signing.

## Nix-Specific Notes

- Format with `nix fmt` (uses treefmt-nix with nixfmt)
- Two configurations: `personal` and `work` (selected via hostname or explicit `--flake .#work`)
- Most of the module graph is shared across `personal` and `work`; even if a change looks profile-specific, run both build checks to protect repo integrity
- Verification commands are `mise run check-personal`, `mise run check-work` and `mise run check-llm-server` (the last one is the only build that evaluates the server-only modules)
- Build-only verification is the maximum allowed agent action; applying the configuration is human-only
- `user.nix` is git skip-worktree'd - edit locally for identity changes
- Unfree packages must be allowlisted in `flake.nix` `allowUnfreePredicate`
- Never run `nix build` without `--no-link` - avoids creating `result` symlinks that clutter the repo
