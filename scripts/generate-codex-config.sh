#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <base-config-path>" >&2
  exit 1
fi

base_config="$1"
config_dir="$HOME/.codex"
config_file="$config_dir/config.toml"
developer_dir="$HOME/Developer"
nix_dir="$HOME/.nix"

mkdir -p "$config_dir"
rm -f "$config_file"
cat "$base_config" > "$config_file"

if [ -d "$nix_dir" ]; then
  printf '\n[projects.\"%s\"]\ntrust_level = \"trusted\"\n' "$nix_dir" >> "$config_file"
fi

if [ -d "$developer_dir" ]; then
  for project in "$developer_dir"/*; do
    [ -d "$project" ] || continue
    printf '\n[projects.\"%s\"]\ntrust_level = \"trusted\"\n' "$project" >> "$config_file"
  done
fi
