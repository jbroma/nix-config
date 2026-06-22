#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <base-config-path> <yq-bin>" >&2
  exit 1
fi

base_config="$1"
yq_bin="$2"
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

"$yq_bin" eval -p=json -o=toml \
  'with_entries(select(.value | tag != "!!map")) | sort_keys(.)' \
  "$merged_config" > "$tmp_file"

"$yq_bin" eval -p=json -o=toml \
  'with_entries(select(.value | tag == "!!map")) | sort_keys(..)' \
  "$merged_config" >> "$tmp_file"

mv "$tmp_file" "$config_file"
