#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/pkg-update.sh [--no-verify]

Updates every custom package in pkgs/ with explicit source handlers:
  - android-studio
  - claude-code
  - claude-desktop
  - cleanshot-x
  - codex-app
  - codex-cli
  - discord
  - minisim
  - vite-plus
  - worktrunk
  - zed-editor

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

sri_to_nix32() {
  nix hash convert --from sri --to nix32 "$1"
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

extract_first_match() {
  local pattern=$1
  local input=$2
  printf '%s' "$input" | rg -o "$pattern" | head -n 1
}

current_version() {
  local file=$1
  rg -o 'version = "[^"]+"' "$file" | head -n 1 | sed -E 's/.*"([^"]+)"/\1/'
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

update_simple_nix32() {
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
  hash=$(sri_to_nix32 "$sri")

  VERSION="$latest" SHA256="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/sha256 = "[^"]+";/sha256 = "$ENV{SHA256}";/;
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

update_android_studio() {
  local file="pkgs/android-studio.nix"
  local page release_path latest dmg_name url sri hash before

  page=$(curl -fsSL https://developer.android.com/studio/releases)
  release_path=$(extract_first_match 'install/[0-9]{4}\.[0-9]\.[0-9]\.[0-9]/android-studio-[[:alnum:]-]+-mac_arm\.dmg' "$page")
  latest=${release_path#install/}
  latest=${latest%%/*}
  dmg_name=${release_path##*/}
  url="https://redirector.gvt1.com/edgedl/android/studio/install/${latest}/${dmg_name}"
  prepare_update "android-studio" "$file" "$latest" "$url" || return 0
  before=$_pkg_update_before
  sri=$(prefetch_sri "$url")
  hash=$(sri_to_hex "$sri")

  VERSION="$latest" DMG_NAME="$dmg_name" SHA256="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/dmgName = "[^"]+";/dmgName = "$ENV{DMG_NAME}";/;
    s/sha256 = "[^"]+";/sha256 = "$ENV{SHA256}";/;
  '

  log_status "android-studio" "$before" "$latest"
}

update_claude_code() {
  local file="pkgs/claude-code.nix"
  local latest url

  latest=$(curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" | jq -r '.version')
  url="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${latest}/darwin-arm64/claude"

  update_simple_sri "claude-code" "$file" "$latest" "$url"
}

update_claude_desktop() {
  REPO_ROOT="$repo_root" bash "$repo_root/scripts/update-claude-desktop.sh"
}

update_cleanshot_x() {
  local file="pkgs/cleanshot-x.nix"
  local page latest url sri hash before

  page=$(curl -fsSL https://cleanshot.com/changelog)
  latest=$(printf '%s' "$page" | perl -ne 'if (/class="number"[^>]*>([0-9]+(?:\.[0-9]+){1,2})</) { print "$1\n"; exit }')
  url="https://updates.getcleanshot.com/v3/CleanShot-X-${latest}.dmg"
  prepare_update "cleanshot-x" "$file" "$latest" "$url" || return 0
  before=$_pkg_update_before
  sri=$(prefetch_sri "$url")
  hash=$(sri_to_hex "$sri")

  VERSION="$latest" SHA256="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/sha256 = "[^"]+";/sha256 = "$ENV{SHA256}";/;
  '

  log_status "cleanshot-x" "$before" "$latest"
}

update_codex_app() {
  local file="pkgs/codex-app.nix"
  local ts url json hash store_path tmp before actual

  ts=$(date +%s)
  url="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg?ts=${ts}"
  ensure_url_exists "$url"
  json=$(prefetch_json "$url" --refresh)
  hash=$(printf '%s' "$json" | jq -r '.hash')
  store_path=$(printf '%s' "$json" | jq -r '.storePath')
  before=$(current_version "$file")

  tmp=$(mktemp -d)
  trap 'hdiutil detach "$tmp/mnt" >/dev/null 2>&1 || true; cleanup_empty_dir "$tmp/mnt"; cleanup_empty_dir "$tmp"' RETURN
  mkdir -p "$tmp/mnt"
  hdiutil attach -mountpoint "$tmp/mnt" -nobrowse -quiet "$store_path"
  actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$tmp/mnt/Codex.app/Contents/Info.plist")
  hdiutil detach "$tmp/mnt" >/dev/null 2>&1 || true
  cleanup_empty_dir "$tmp/mnt"
  cleanup_empty_dir "$tmp"
  trap - RETURN

  VERSION="$actual" HASH="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/hash = "sha256-[^"]+";/hash = "$ENV{HASH}";/;
  '

  log_status "codex-app" "$before" "$actual"
}

update_codex_cli() {
  local file="pkgs/codex-cli.nix"
  local latest url

  latest=$(gh api repos/openai/codex/releases/latest --jq '.tag_name' | sed 's/^rust-v//')
  url="https://github.com/openai/codex/releases/download/rust-v${latest}/codex-aarch64-apple-darwin.tar.gz"
  update_simple_sri "codex-cli" "$file" "$latest" "$url"
}

update_discord() {
  REPO_ROOT="$repo_root" bash "$repo_root/scripts/update-discord.sh"
}

update_minisim() {
  local file="pkgs/minisim.nix"
  local latest url

  latest=$(gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/okwasniewski/MiniSim/releases/download/v${latest}/MiniSim.app.zip"
  update_simple_hex "minisim" "$file" "$latest" "$url"
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

update_zed_editor() {
  local file="pkgs/zed-editor.nix"
  local latest url sri hash before

  latest=$(gh api repos/zed-industries/zed/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/zed-industries/zed/releases/download/v${latest}/Zed-aarch64.dmg"
  prepare_update "zed-editor" "$file" "$latest" "$url" || return 0
  before=$_pkg_update_before
  sri=$(prefetch_sri "$url")
  hash=$(sri_to_nix32 "$sri")

  VERSION="$latest" SHA256="$hash" replace_in_file "$file" '
    s|url = "https://github.com/zed-industries/zed/releases/download/v[^"]+/Zed-aarch64\.dmg";|url = "https://github.com/zed-industries/zed/releases/download/v$ENV{VERSION}/Zed-aarch64.dmg";|;
    s|sha256 = "[^"]+";|sha256 = "$ENV{SHA256}";|;
    s|version = "[^"]+";|version = "$ENV{VERSION}";|;
  '

  log_status "zed-editor" "$before" "$latest"
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

verify=true

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

update_android_studio
update_claude_code
update_claude_desktop
update_cleanshot_x
update_codex_app
update_codex_cli
update_discord
update_minisim
update_vite_plus
update_worktrunk
update_zed_editor

if [[ "$verify" == true ]]; then
  echo ""
  echo "Verifying darwin configurations..."
  nix build .#darwinConfigurations.personal.system --no-link
  nix build .#darwinConfigurations.work.system --no-link
fi
