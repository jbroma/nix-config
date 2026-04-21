#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <vite-plus-home> <version> <source-vp>" >&2
  exit 1
fi

vite_plus_home="$1"
version="$2"
source_vp="$3"

version_dir="$vite_plus_home/$version"
version_bin_dir="$version_dir/bin"
version_vp="$version_bin_dir/vp"
top_bin_dir="$vite_plus_home/bin"
top_vp="$top_bin_dir/vp"
current_link="$vite_plus_home/current"
install_log="$version_dir/install.log"
installed_package_json="$version_dir/node_modules/vite-plus/package.json"

mkdir -p "$version_bin_dir" "$top_bin_dir"
rm -f "$version_bin_dir/vp-real"
install -m 755 "$source_vp" "$version_vp"

cat > "$version_dir/package.json" <<EOF
{
  "name": "vp-global",
  "version": "$version",
  "private": true,
  "dependencies": {
    "vite-plus": "$version"
  }
}
EOF

cat > "$version_dir/.npmrc" <<'EOF'
minimum-release-age=0
min-release-age=0
EOF

# Older installs left ~/.vite-plus/bin/vp as a symlink to ../current/bin/vp.
# Remove it before writing the guard wrapper, or the redirection would overwrite
# the real versioned binary and recreate the recursion bug.
rm -f "$top_vp"

cat > "$top_vp" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

install_root="${VITE_PLUS_HOME:-$HOME/.vite-plus}"
real_vp="$install_root/current/bin/vp"

case "${1:-}" in
  upgrade)
    echo "error: 'vp upgrade' is disabled because Vite+ is managed by Nix in this repo." >&2
    echo "Update the pinned Vite+ package in ~/.nix and rebuild instead." >&2
    exit 1
    ;;
  implode)
    echo "error: 'vp implode' is disabled because Vite+ is managed by Nix in this repo." >&2
    echo "Remove the Vite+ Home Manager wiring in ~/.nix and rebuild instead." >&2
    exit 1
    ;;
esac

export VITE_PLUS_HOME="$install_root"
exec "$real_vp" "$@"
EOF
chmod +x "$top_vp"

needs_install=1
if [ -f "$installed_package_json" ] && grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"$version\"" "$installed_package_json"; then
  needs_install=0
fi

if [ "$needs_install" -eq 1 ]; then
  rm -f "$install_log"
  if ! (
    cd "$version_dir" &&
      CI=true VITE_PLUS_HOME="$vite_plus_home" "$version_vp" install --silent > "$install_log" 2>&1
  ); then
    echo "error: failed to bootstrap Vite+ $version. See $install_log" >&2
    exit 1
  fi
fi

ln -sfn "$version" "$current_link"

if ! VITE_PLUS_HOME="$vite_plus_home" "$version_vp" env setup --env-only > /dev/null 2>&1; then
  echo "error: failed to refresh Vite+ environment files under $vite_plus_home" >&2
  exit 1
fi

cleanup_old_versions() {
  local max_versions=5
  local versions=()
  local semver_regex='^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?$'
  local dir name count delete_count

  for dir in "$vite_plus_home"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    if [ "$dir" = "$version_dir/" ]; then
      continue
    fi
    if [[ "$name" =~ $semver_regex ]]; then
      versions+=("$dir")
    fi
  done

  count=${#versions[@]}
  if [ "$count" -lt "$max_versions" ]; then
    return 0
  fi

  dir_sort_key() {
    local target="$1"

    if stat --format='%W' "$target" >/dev/null 2>&1; then
      local birth
      birth="$(stat --format='%W' "$target")"
      if [ "$birth" != "-1" ]; then
        printf '%s\n' "$birth"
        return 0
      fi

      stat --format='%Y\n' "$target"
      return 0
    fi

    if stat -f '%B' "$target" >/dev/null 2>&1; then
      printf '%s\n' "$(stat -f '%B' "$target")"
      return 0
    fi

    stat -f '%m\n' "$target"
  }

  delete_count=$((count - max_versions + 1))
  while IFS= read -r old_version; do
    rm -rf "$old_version"
  done < <(
    for dir in "${versions[@]}"; do
      printf '%s %s\n' "$(dir_sort_key "$dir")" "$dir"
    done | sort -n | head -n "$delete_count" | cut -d' ' -f2-
  )
}

cleanup_old_versions
