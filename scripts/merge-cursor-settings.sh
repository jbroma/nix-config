#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <target-settings-path> <managed-settings-path> <jq-bin>" >&2
  exit 1
fi

target_settings_path="$1"
managed_settings_path="$2"
jq_bin="$3"
target_settings_dir="$(dirname "$target_settings_path")"

mkdir -p "$target_settings_dir"

# Replace old Home Manager symlink with a real mutable file.
if [ -L "$target_settings_path" ]; then
  rm -f "$target_settings_path"
fi

# Bootstrap from managed settings if settings file does not exist yet.
if [ ! -f "$target_settings_path" ]; then
  cat "$managed_settings_path" > "$target_settings_path"
  exit 0
fi

if existing_settings_json="$("$jq_bin" -c '.' "$target_settings_path" 2>/dev/null)"; then
  :
else
  existing_settings_json='{}'
fi

managed_settings_json="$("$jq_bin" -c '.' "$managed_settings_path")"
tmp_file="$(mktemp "${target_settings_path}.tmp.XXXXXX")"

"$jq_bin" -n \
  --argjson existing "$existing_settings_json" \
  --argjson managed "$managed_settings_json" \
  '($existing // {}) * ($managed // {})' > "$tmp_file"

mv "$tmp_file" "$target_settings_path"
