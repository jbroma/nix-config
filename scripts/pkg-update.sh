#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/pkg-update.sh [--no-verify]

Updates every custom package in pkgs/ with explicit source handlers:
  - claude-code
  - codex-cli
  - maestro-studio
  - minisim
  - spotify
  - vite-plus
  - worktrunk

By default, runs:
  nix build .#darwinConfigurations.personal.system --no-link
  nix build .#darwinConfigurations.work.system --no-link

Options:
  --no-verify   Skip the darwin verification builds
  -h, --help    Show this help text
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

ensure_url_exists() {
  curl -fsSIL "$1" >/dev/null
}

prefetch_json() {
  local url=$1
  shift || true
  nix store prefetch-file --json "$@" "$url"
}

prefetch_sri() {
  local url=$1
  shift || true
  prefetch_json "$url" "$@" | jq -r '.hash'
}

sri_to_hex() {
  nix hash convert --from sri --to base16 "$1"
}

replace_in_file() {
  local file=$1
  local script=$2
  perl -0pi -e "$script" "$file"
}

cleanup_empty_dir() {
  local dir=$1
  if [[ -d "$dir" ]]; then
    rmdir "$dir" 2>/dev/null || true
  fi
}

current_version() {
  local file=$1
  rg -o 'version = "[^"]+"' "$file" | head -n 1 | sed -E 's/.*"([^"]+)"/\1/'
}

current_sri_hash() {
  local file=$1
  rg -o 'hash = "sha256-[^"]+"' "$file" | head -n 1 | sed -E 's/.*"(sha256-[^"]+)"/\1/'
}

read_dmg_info_plist_key() {
  local dmg_path=$1
  local app_name=$2
  local key=$3
  local tmp mount app_bundle value

  tmp=$(mktemp -d)
  mount="$tmp/mnt"
  mkdir -p "$mount"

  trap 'hdiutil detach "$mount" >/dev/null 2>&1 || true; cleanup_empty_dir "$mount"; cleanup_empty_dir "$tmp"' RETURN
  hdiutil attach -mountpoint "$mount" -nobrowse -quiet "$dmg_path"
  app_bundle="$mount/${app_name}"
  if [[ ! -f "$app_bundle/Contents/Info.plist" ]]; then
    app_bundle=$(find "$mount" -maxdepth 3 -type d -name "$app_name" -print -quit)
  fi
  if [[ -z "$app_bundle" || ! -f "$app_bundle/Contents/Info.plist" ]]; then
    echo "error: failed to locate ${app_name}/Contents/Info.plist in ${dmg_path}" >&2
    exit 1
  fi
  value=$(/usr/libexec/PlistBuddy -c "Print :${key}" "$app_bundle/Contents/Info.plist")
  hdiutil detach "$mount" >/dev/null 2>&1 || true
  cleanup_empty_dir "$mount"
  cleanup_empty_dir "$tmp"
  trap - RETURN

  printf '%s\n' "$value"
}

prepare_update() {
  local name=$1
  local file=$2
  local latest=$3
  local url=$4

  _pkg_update_before=$(current_version "$file")
  if [[ "$_pkg_update_before" == "$latest" ]]; then
    log_status "$name" "$_pkg_update_before" "$latest"
    return 1
  fi

  ensure_url_exists "$url"
}

update_simple_sri() {
  local name=$1
  local file=$2
  local latest=$3
  local url=$4
  local hash
  local before

  prepare_update "$name" "$file" "$latest" "$url" || return 0
  before=$_pkg_update_before
  hash=$(prefetch_sri "$url")

  VERSION="$latest" HASH="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/hash = "sha256-[^"]+";/hash = "$ENV{HASH}";/;
  '

  log_status "$name" "$before" "$latest"
}

update_simple_hex() {
  local name=$1
  local file=$2
  local latest=$3
  local url=$4
  local sri
  local hash
  local before

  prepare_update "$name" "$file" "$latest" "$url" || return 0
  before=$_pkg_update_before
  sri=$(prefetch_sri "$url")
  hash=$(sri_to_hex "$sri")

  VERSION="$latest" SHA256="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/sha256 = "[^"]+";/sha256 = "$ENV{SHA256}";/;
  '

  log_status "$name" "$before" "$latest"
}

update_claude_code() {
  local file="pkgs/claude-code.nix"
  local latest url

  latest=$(curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" | jq -r '.version')
  url="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${latest}/darwin-arm64/claude"

  update_simple_sri "claude-code" "$file" "$latest" "$url"
}

update_codex_cli() {
  local file="pkgs/codex-cli.nix"
  local latest url

  latest=$(gh api repos/openai/codex/releases/latest --jq '.tag_name' | sed 's/^rust-v//')
  url="https://github.com/openai/codex/releases/download/rust-v${latest}/codex-aarch64-apple-darwin.tar.gz"
  update_simple_sri "codex-cli" "$file" "$latest" "$url"
}

update_minisim() {
  local file="pkgs/minisim.nix"
  local latest url

  latest=$(gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/okwasniewski/MiniSim/releases/download/v${latest}/MiniSim.app.zip"
  update_simple_hex "minisim" "$file" "$latest" "$url"
}

update_maestro_studio() {
  local file="pkgs/maestro-studio.nix"
  local release_json latest url digest sha256 before

  release_json=$(gh api repos/mobile-dev-inc/maestro-studio/releases/latest)
  latest=$(printf '%s' "$release_json" | jq -r '.tag_name' | sed 's/^v//')
  url=$(printf '%s' "$release_json" | jq -r '.assets[] | select(.name=="Maestro-Studio-mac-universal.zip") | .browser_download_url')
  digest=$(printf '%s' "$release_json" | jq -r '.assets[] | select(.name=="Maestro-Studio-mac-universal.zip") | .digest')

  if [[ -z "$latest" || "$latest" == "null" || -z "$url" || "$url" == "null" || -z "$digest" || "$digest" == "null" ]]; then
    echo "error: failed to resolve Maestro Studio release metadata" >&2
    exit 1
  fi

  sha256=${digest#sha256:}
  prepare_update "maestro-studio" "$file" "$latest" "$url" || return 0
  before=$_pkg_update_before

  VERSION="$latest" SHA256="$sha256" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/sha256 = "[^"]+";/sha256 = "$ENV{SHA256}";/;
  '

  log_status "maestro-studio" "$before" "$latest"
}

update_spotify() {
  local file="pkgs/spotify.nix"
  local url json hash store_path before current_hash actual

  url="https://download.scdn.co/SpotifyARM64.dmg"
  ensure_url_exists "$url"
  json=$(prefetch_json "$url" --refresh)
  hash=$(printf '%s' "$json" | jq -r '.hash')
  store_path=$(printf '%s' "$json" | jq -r '.storePath')
  before=$(current_version "$file")
  current_hash=$(current_sri_hash "$file")
  actual=$(read_dmg_info_plist_key "$store_path" "Spotify.app" "CFBundleVersion")

  if [[ "$before" == "$actual" && "$current_hash" == "$hash" ]]; then
    log_status "spotify" "$before" "$actual"
    return 0
  fi

  VERSION="$actual" HASH="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/hash = "sha256-[^"]+";/hash = "$ENV{HASH}";/;
  '

  if [[ "$before" == "$actual" ]]; then
    printf '  %-15s %s (artifact refreshed)\n' "spotify" "$actual"
  else
    log_status "spotify" "$before" "$actual"
  fi
}

update_vite_plus() {
  local file="pkgs/vite-plus.nix"
  local latest url

  latest=$(curl -fsSL "https://registry.npmjs.org/@voidzero-dev%2Fvite-plus-cli-darwin-arm64/latest" | jq -r '.version')
  url="https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-darwin-arm64/-/vite-plus-cli-darwin-arm64-${latest}.tgz"
  update_simple_sri "vite-plus" "$file" "$latest" "$url"
}

update_worktrunk() {
  local file="pkgs/worktrunk.nix"
  local latest url

  latest=$(gh api repos/max-sixty/worktrunk/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/max-sixty/worktrunk/releases/download/v${latest}/worktrunk-aarch64-apple-darwin.tar.xz"
  update_simple_sri "worktrunk" "$file" "$latest" "$url"
}

log_status() {
  local name=$1
  local before=$2
  local after=$3

  if [[ "$before" == "$after" ]]; then
    printf '  %-15s %s (unchanged)\n' "$name" "$after"
  else
    printf '  %-15s %s -> %s\n' "$name" "$before" "$after"
  fi
}

run_isolated_handler() {
  local source_file=$1
  local working_directory=$2
  local handler=$3

  "$BASH" -c '
    set -euo pipefail
    source "$1"
    repo_root=$2
    cd "$repo_root"
    "$3"
  ' pkg-update-handler "$source_file" "$working_directory" "$handler"
}

main() {
  local verify=true
  local update_specs=(
    "claude-code:update_claude_code"
    "codex-cli:update_codex_cli"
    "minisim:update_minisim"
    "maestro-studio:update_maestro_studio"
    "spotify:update_spotify"
    "vite-plus:update_vite_plus"
    "worktrunk:update_worktrunk"
  )
  local failed_steps=()
  local spec name handler status

  while (($#)); do
    case "$1" in
      --no-verify)
        verify=false
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "error: unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  require_cmd curl
  require_cmd gh
  require_cmd hdiutil
  require_cmd jq
  require_cmd nix
  require_cmd perl
  require_cmd rg

  repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  cd "$repo_root"

  echo "Updating packages in pkgs/..."

  for spec in "${update_specs[@]}"; do
    name=${spec%%:*}
    handler=${spec#*:}

    if run_isolated_handler "$repo_root/scripts/pkg-update.sh" "$repo_root" "$handler"; then
      continue
    else
      status=$?
    fi

    printf '  %-15s failed (exit %s)\n' "$name" "$status" >&2
    failed_steps+=("$name")
  done

  if [[ "$verify" == true ]]; then
    echo ""
    echo "Verifying darwin configurations..."

    if ! nix build .#darwinConfigurations.personal.system --no-link; then
      failed_steps+=("personal verification")
    fi

    if ! nix build .#darwinConfigurations.work.system --no-link; then
      failed_steps+=("work verification")
    fi
  fi

  if ((${#failed_steps[@]} > 0)); then
    echo "" >&2
    echo "Completed with failures:" >&2
    printf '  - %s\n' "${failed_steps[@]}" >&2
    return 1
  fi

  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
