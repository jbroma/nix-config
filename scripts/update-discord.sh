#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

current_value() {
  local pattern=$1
  local file=$2
  rg -o "$pattern" "$file" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/'
}

replace_in_file() {
  local file=$1
  local script=$2
  perl -0pi -e "$script" "$file"
}

require_cmd curl
require_cmd jq
require_cmd nix
require_cmd perl
require_cmd rg

repo_root=${REPO_ROOT:-}
if [[ -z "$repo_root" ]]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi

if [[ -z "$repo_root" || ! -f "$repo_root/pkgs/discord.nix" ]]; then
  echo "error: could not locate repo root containing pkgs/discord.nix" >&2
  exit 1
fi

file="$repo_root/pkgs/discord.nix"
before_version=$(current_value 'version = "[^"]+"' "$file")
before_hash=$(current_value 'hash = "sha256-[^"]+"' "$file")

resolved_url=$(curl -fsSIL -o /dev/null -w '%{url_effective}' "https://discord.com/api/download/stable?platform=osx&format=dmg")
latest_version=$(printf '%s' "$resolved_url" | sed -E 's|.*/([0-9]+(\.[0-9]+)*)/Discord\.dmg$|\1|')

if [[ "$latest_version" == "$resolved_url" ]]; then
  echo "error: failed to extract Discord version from resolved URL: $resolved_url" >&2
  exit 1
fi

latest_hash=$(nix store prefetch-file --json "$resolved_url" | jq -r '.hash')

if [[ "$before_version" == "$latest_version" && "$before_hash" == "$latest_hash" ]]; then
  printf '  %-15s %s (unchanged)\n' "discord" "$latest_version"
  exit 0
fi

VERSION="$latest_version" HASH="$latest_hash" replace_in_file "$file" '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/hash = "sha256-[^"]+";/hash = "$ENV{HASH}";/;
'

if [[ "$before_version" == "$latest_version" ]]; then
  printf '  %-15s %s (hash refreshed)\n' "discord" "$latest_version"
else
  printf '  %-15s %s -> %s\n' "discord" "$before_version" "$latest_version"
fi
