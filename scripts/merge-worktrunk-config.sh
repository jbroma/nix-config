#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <managed-config-path> <target-config-path> <remarshal-bin> <jq-bin>" >&2
  exit 1
fi

managed_config="$1"
target_config="$2"
remarshal_bin="$3"
jq_bin="$4"
target_dir="$(dirname "$target_config")"

mkdir -p "$target_dir"

# Replace old Home Manager symlink with a real mutable file.
if [ -L "$target_config" ]; then
  rm -f "$target_config"
fi

# First run bootstrap: copy the managed dotfile as baseline.
if [ ! -f "$target_config" ]; then
  cat "$managed_config" > "$target_config"
  exit 0
fi

tmp_file="$(mktemp "${target_config}.tmp.XXXXXX")"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

# Merge strategy:
# - Any top-level key present in managed config is replaced wholesale.
# - Top-level keys absent from managed config are preserved from existing config.
# This keeps managed sections deterministic while preserving unrelated user state.
existing_json="$("$remarshal_bin" -if toml -of json < "$target_config")"
managed_json="$("$remarshal_bin" -if toml -of json < "$managed_config")"

"$jq_bin" -n \
  --argjson existing "$existing_json" \
  --argjson managed "$managed_json" \
  '
  ($existing // {}) as $existing_obj |
  ($managed // {}) as $managed_obj |
  reduce ($managed_obj | keys_unsorted[]) as $key ($existing_obj; .[$key] = $managed_obj[$key])
  ' \
  | "$remarshal_bin" -if json -of toml > "$tmp_file"

mv "$tmp_file" "$target_config"
trap - EXIT
