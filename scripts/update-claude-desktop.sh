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

if [[ -z "$repo_root" || ! -f "$repo_root/pkgs/claude-desktop.nix" ]]; then
  echo "error: could not locate repo root containing pkgs/claude-desktop.nix" >&2
  exit 1
fi

file="$repo_root/pkgs/claude-desktop.nix"
before_version=$(current_value 'version = "[^"]+"' "$file")
before_hash=$(current_value 'hash = "sha256-[^"]+"' "$file")
before_url=$(current_value 'url = "https://downloads\.claude\.ai/releases/darwin/universal/[^"]+/Claude-[^"]+\.zip"' "$file")

release_json=$(curl -fsSL "https://downloads.claude.ai/releases/darwin/universal/RELEASES.json")
latest_version=$(printf '%s' "$release_json" | jq -r '.currentRelease')
latest_url=$(printf '%s' "$release_json" | jq -r --arg version "$latest_version" '.releases[] | select(.version == $version) | .updateTo.url')

if [[ -z "$latest_version" || "$latest_version" == "null" || -z "$latest_url" || "$latest_url" == "null" ]]; then
  echo "error: failed to resolve latest Claude Desktop release from RELEASES.json" >&2
  exit 1
fi

latest_build=$(printf '%s' "$latest_url" | sed -E 's|.*/Claude-([[:xdigit:]]+)\.zip$|\1|')
if [[ -z "$latest_build" || "$latest_build" == "$latest_url" ]]; then
  echo "error: failed to extract Claude Desktop build id from $latest_url" >&2
  exit 1
fi

latest_hash=$(nix store prefetch-file --json --refresh "$latest_url" | jq -r '.hash')

if [[ "$before_version" == "$latest_version" && "$before_hash" == "$latest_hash" && "$before_url" == "$latest_url" ]]; then
  printf '  %-15s %s (unchanged)\n' "claude-desktop" "$latest_version"
  exit 0
fi

VERSION="$latest_version" BUILD_ID="$latest_build" HASH="$latest_hash" replace_in_file "$file" '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s|url = "https://downloads\.claude\.ai/releases/darwin/universal/[^"]+/Claude-[^"]+\.zip";|url = "https://downloads.claude.ai/releases/darwin/universal/$ENV{VERSION}/Claude-$ENV{BUILD_ID}.zip";|;
  s/hash = "sha256-[^"]+";/hash = "$ENV{HASH}";/;
'

if [[ "$before_version" == "$latest_version" ]]; then
  printf '  %-15s %s (artifact refreshed)\n' "claude-desktop" "$latest_version"
else
  printf '  %-15s %s -> %s\n' "claude-desktop" "$before_version" "$latest_version"
fi
