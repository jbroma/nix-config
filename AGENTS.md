# AGENTS.md

This file provides guidance to AI coding assistants when working with code in this repository.

## Repository Purpose

Personal macOS dotfiles configuration using Nix Flakes, nix-darwin, and home-manager. Scope is strictly dotfiles management - all development environments use Docker Compose (see `devops-patterns` skill).

## Commands

```bash
# Primary workflow
mise run switch              # Rebuild and apply darwin configuration
mise run check               # Check config without applying
mise run update              # Update flake inputs

# Shell aliases (after setup)
darwin-rebuild-switch        # Same as mise run switch
darwin-cleanup               # Prune generations older than 7 days
flake-update                 # Same as mise run update
```

## Architecture

```
flake.nix                    # Entry point - two configs: work, personal
├── configuration.nix        # System-level (nix-darwin): packages, services, security
├── home.nix                 # User-level entry: imports home-manager modules
├── user.nix                 # User identity (git skip-worktree, not committed)
│
├── home-manager/            # Home-manager modules
│   ├── claude-code.nix      # Claude Code: settings, hooks, skills, plugins
│   ├── gemini.nix           # Gemini CLI: rules symlinks
│   ├── cursor.nix           # Cursor: settings, extensions, .cursorrules
│   ├── zsh.nix              # Shell config with modern CLI aliases
│   └── [tool].nix           # Per-tool configurations
│
├── macos/                   # macOS system preferences modules
├── pkgs/                    # Custom package derivations (auto-loaded by flake)
├── dotfiles/                # Non-Nix config files (sketchybar, oh-my-posh, vscode)
└── ai/                      # Nix flake input (ai-sauce) - skills, agents, rules
```

**Key patterns:**

-   `specialArgs = { inherit type user; }` passes profile type (work/personal) and user info to all modules
-   Custom packages in `./pkgs/` are auto-loaded via `mapAttrs'` over the directory
-   Overlays substitute: `ghostty-bin`, `code-cursor`, archived Spotify ARM64 build

## AI Integration

The `ai/` directory is a Nix flake input providing shared configuration for AI coding tools. Each tool has its own home-manager module that symlinks relevant parts:

-   `claude-code.nix`: `~/.claude/skills`, `~/.claude/hooks`, `~/.claude/CLAUDE.md`
-   `gemini.nix`: `~/.gemini/rules`, `~/.gemini/GEMINI.md`
-   `cursor.nix`: `~/.cursorrules`

The `ai` input is also symlinked to `~/.nix/ai` for visibility (in `home.nix`).

## Nix-Specific Notes

-   Format with `nix fmt` (uses treefmt-nix with nixfmt)
-   Two configurations: `personal` and `work` (selected via hostname or explicit `--flake .#work`)
-   `user.nix` is git skip-worktree'd - edit locally for identity changes
-   Unfree packages must be allowlisted in `flake.nix` `allowUnfreePredicate`
-   Never run `nix build` without `--no-link` - avoids creating `result` symlinks that clutter the repo
