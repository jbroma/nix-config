---
name: local-cleanup
description: Check that this machine matches ~/.nix and clean up what drifted - unpushed or stale git, an unapplied system, leftover MCP servers, Keychain keys and allow rules after removing a tool. Use after changing tools or MCP servers, or when asked to verify the setup is up to date.
allowed-tools: Bash, Read, Edit, Grep
---

# Local cleanup

1. Run `mise run drift`. It is read-only and prints one `ok` or `DRIFT` line per check.
2. Fix each `DRIFT` line by its owner:

| Finding | Fix |
| --- | --- |
| `~/.nix` uncommitted, ahead or behind | Commit, push or pull, following the repo's Git Workflow. |
| ai input behind ai-sauce main | `mise run ai-update`, both build checks, commit `flake.lock`. |
| Applied system differs | The user runs `darwin-rebuild-switch`. Agents never apply. |
| Tool config has servers Nix does not declare | If Nix used to declare it, make activation remove it: for Codex, add `.mcp_servers.<name>` to the `del(...)` list in `scripts/generate-codex-config.sh`. If a tool added the server on its own, leave it and add the name to the script's ignore list next to Codex's `cua_repl` and `node_repl`. |
| Unused Keychain API key | Give the user the `security delete-generic-password -s <name> -a "$USER"` command. Do not read or delete credentials yourself. |
| Allow list names a removed server | Edit the file. `.claude/settings.local.json` is untracked; `~/.claude/settings.json` is generated, so fix its source in ai-sauce `rules/rules.yaml` and run `rules/generate.sh`. |

3. After repo edits, run `mise run check-personal` and `mise run check-work`, then `mise run drift` again. Findings that wait on `darwin-rebuild-switch` stay until the user applies.
4. Report what you fixed and list the commands left for the user, in order.

When a new kind of leftover turns up that the script misses, add a check to `scripts/local-drift.sh` instead of fixing it by hand only.
