#!/usr/bin/env bash
# Report where this machine has drifted from the repo: unpushed or unpulled commits,
# an unapplied system, and leftovers of removed MCP servers in tool configs,
# Keychain items and allow lists. Read-only; prints one line per finding.
set -uo pipefail
cd "$(dirname "$0")/.."

drift=0
report() { echo "DRIFT  $*"; drift=1; }
ok() { echo "ok     $*"; }

# Git: ~/.nix against origin and the locked ai-sauce revision.
git fetch -q origin 2>/dev/null
read -r behind ahead < <(git rev-list --left-right --count '@{u}...HEAD')
[ "$ahead$behind" = 00 ] && ok "~/.nix in sync with origin" || report "~/.nix is $ahead ahead, $behind behind origin"
locked=$(jq -r .nodes.ai.locked.rev flake.lock)
remote=$(git ls-remote "$(jq -r '.nodes.ai.original.url' flake.lock)" refs/heads/main | cut -f1)
[ "$locked" = "$remote" ] && ok "ai input at ai-sauce main" || report "ai input locked at ${locked:0:7}, ai-sauce main is ${remote:0:7} (mise run ai-update)"

# Applied system: does /run/current-system match a fresh evaluation of either profile?
current=$(readlink /run/current-system)
profile=""
for p in personal work; do
  [ "$(nix eval --raw --option eval-cache false ".#darwinConfigurations.$p.system.outPath" 2>/dev/null)" = "$current" ] && profile=$p
done
[ -n "$profile" ] && ok "applied system matches $profile" || report "applied system differs from the repo (darwin-rebuild-switch)"

# MCP servers: Nix is the source of truth; anything else in a tool config is a leftover.
hm=".#darwinConfigurations.${profile:-personal}.config.home-manager.users.$USER.mcp"
expected=$(nix eval --json "$hm.servers" --apply builtins.attrNames | jq -r '.[]' | sort)
services=$(nix eval --json "$hm.secrets" --apply 's: map (x: x.service) (builtins.attrValues s)' | jq -r '.[]' | sort)
check_servers() { # <label> <names...>
  local label=$1 extra; shift
  extra=$(comm -13 <(echo "$expected") <(printf '%s\n' "$@" | sort -u | grep .))
  [ -z "$extra" ] && ok "$label MCP servers" || report "$label has MCP servers Nix does not declare: $(echo $extra)"
}
check_servers ~/.claude.json $(jq -r '.mcpServers // {} | keys[]' ~/.claude.json)
check_servers ~/.cursor/mcp.json $(jq -r '.mcpServers // {} | keys[]' ~/.cursor/mcp.json)
# The Codex app adds cua_repl and node_repl on its own.
check_servers ~/.codex/config.toml $(yq -p=toml -o=yaml '.mcp_servers // {} | keys | .[]' ~/.codex/config.toml | grep -v -x -e cua_repl -e node_repl)

# Keychain: *-api-key items for this user that no MCP secret uses.
stale=$(comm -13 <(echo "$services") <(security dump-keychain 2>/dev/null |
  awk -F'"' '/"acct"<blob>=/{a=$4} /"svce"<blob>=/{s=$4} /^keychain:/{if(a==ENVIRON["USER"]&&s~/-api-key$/)print s; a=s=""} END{if(a==ENVIRON["USER"]&&s~/-api-key$/)print s}' | sort -u))
[ -z "$stale" ] && ok "Keychain API keys" || report "Keychain has unused API keys: $(echo $stale) (security delete-generic-password -s <name> -a \$USER)"

# Allow lists: mcp__<server>__ rules for servers that are gone (plugins and claude.ai connectors excluded).
for f in ~/.claude/settings.json .claude/settings.local.json; do
  [ -f "$f" ] || continue
  gone=$(jq -r '.permissions.allow[]? | capture("^mcp__(?<s>[^_]+)__").s' "$f" | grep -v -e '^plugin$' -e '^claude$' | sort -u | comm -23 - <(echo "$expected"))
  [ -z "$gone" ] && ok "$f allow list" || report "$f allows removed MCP servers: $(echo $gone)"
done

exit $drift
