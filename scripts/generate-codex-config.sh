#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <base-config-path> <mcp-secrets.tsv> <yq-bin>" >&2
  exit 1
fi

base_config="$1"
secrets_tsv="$2"
yq_bin="$3"
config_dir="$HOME/.codex"
config_file="$config_dir/config.toml"
developer_dir="$HOME/Developer"
nix_dir="$HOME/.nix"

mkdir -p "$config_dir"

tmp_file="$(mktemp "${config_file}.tmp.XXXXXX")"
projects_config="$(mktemp "${config_file}.projects.XXXXXX")"
existing_config="$(mktemp "${config_file}.existing.XXXXXX")"
merged_config="$(mktemp "${config_file}.merged.XXXXXX")"

cleanup() {
  rm -f "$tmp_file" "$projects_config" "$existing_config" "$merged_config"
}
trap cleanup EXIT

: > "$projects_config"

if [ -d "$nix_dir" ]; then
  printf '\n[projects.\"%s\"]\ntrust_level = \"trusted\"\n' "$nix_dir" >> "$projects_config"
fi

if [ -d "$developer_dir" ]; then
  for project in "$developer_dir"/*; do
    [ -d "$project" ] || continue
    printf '\n[projects.\"%s\"]\ntrust_level = \"trusted\"\n' "$project" >> "$projects_config"
  done
fi

if [ -f "$config_file" ] && "$yq_bin" eval -p=toml '.' "$config_file" >/dev/null 2>&1; then
  "$yq_bin" eval -p=toml -o=toml 'del(.projects)' "$config_file" > "$existing_config"
  merge_inputs=("$existing_config" "$base_config" "$projects_config")
else
  merge_inputs=("$base_config" "$projects_config")
fi

"$yq_bin" eval-all -p=toml -o=json \
  '. as $item ireduce ({}; . * $item)' \
  "${merge_inputs[@]}" > "$merged_config"

# Servers declared in the base config replace the existing entry wholesale. The deep
# merge above would keep stale keys (an old stdio `command` next to a new `url`),
# which Codex rejects. Servers the Codex app adds on its own are left untouched.
base_json="$(mktemp "${config_file}.base.XXXXXX")"
"$yq_bin" eval -p=toml -o=json '.' "$base_config" > "$base_json"
for name in $("$yq_bin" eval -p=json -o=yaml '.mcp_servers // {} | keys | .[]' "$base_json"); do
  name="$name" base_json="$base_json" "$yq_bin" eval -i -p=json -o=json \
    '.mcp_servers[strenv(name)] = load(strenv(base_json)).mcp_servers[strenv(name)]' "$merged_config"
done
rm -f "$base_json"

# Keychain-backed MCP headers: <server> <header> <keychain service> <prefix> (tab-separated, prefix may be empty).
while IFS=$'\t' read -r server header service prefix; do
  [ -n "$server" ] || continue
  key="$(/usr/bin/security find-generic-password -s "$service" -a "$USER" -w 2>/dev/null </dev/null || true)"
  [ -n "$key" ] || continue
  server="$server" header="$header" value="$prefix$key" "$yq_bin" eval -i -p=json -o=json \
    '(.mcp_servers[strenv(server)] | select(. != null)).http_headers[strenv(header)] = strenv(value)' \
    "$merged_config"
done < "$secrets_tsv"

"$yq_bin" eval -p=json -o=toml \
  'with_entries(select(.value | tag != "!!map")) | sort_keys(.)' \
  "$merged_config" > "$tmp_file"

"$yq_bin" eval -p=json -o=toml \
  'with_entries(select(.value | tag == "!!map")) | sort_keys(..)' \
  "$merged_config" >> "$tmp_file"

mv "$tmp_file" "$config_file"
