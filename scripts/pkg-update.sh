#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/pkg-update.sh [--no-verify]

Updates the following packages and lists packages requiring manual updates:
  - agent-browser
  - agent-device
  - apple-container
  - claude-code
  - cleanshot (4.x only)
  - codex-cli
  - cursor-cli
  - maestro-studio
  - minisim
  - vite-plus
  - wsmancli

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

replace_in_file() {
  local file=$1
  local script=$2
  perl -0pi -e "$script" "$file"
}

current_version() {
  local file=$1
  local n=${2:-1}
  rg -o 'version = "[^"]+"' "$file" | sed -n "${n}p" | sed -E 's/.*"([^"]+)"/\1/'
}

# Sets the value of the n-th `key = "...";` in a file with several versions or hashes.
set_nth() {
  local file=$1
  local key=$2
  local n=$3
  local value=$4

  KEY="$key" N="$n" VALUE="$value" replace_in_file "$file" '
    my $i = 0;
    s/(\b\Q$ENV{KEY}\E = ")[^"]+(";)/++$i == $ENV{N} ? "$1$ENV{VALUE}$2" : $&/ge;
  '
}

update_simple_sri() {
  local name=$1
  local file=$2
  local latest=$3
  local url=$4
  local hash
  local before

  before=$(current_version "$file")
  if [[ "$before" == "$latest" ]]; then
    log_status "$name" "$before" "$latest"
    return 0
  fi

  ensure_url_exists "$url"
  hash=$(prefetch_sri "$url")

  VERSION="$latest" HASH="$hash" replace_in_file "$file" '
    s/version = "[^"]+";/version = "$ENV{VERSION}";/;
    s/hash = "sha256-[^"]+";/hash = "$ENV{HASH}";/;
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
  url="https://github.com/openai/codex/releases/download/rust-v${latest}/codex-package-aarch64-apple-darwin.tar.gz"
  update_simple_sri "codex-cli" "$file" "$latest" "$url"
}

update_cursor_cli() {
  local file="pkgs/cursor-cli.nix"
  local latest url

  latest=$(curl -fsSL https://cursor.com/install | rg -o -m1 'downloads\.cursor\.com/lab/[^/]+' | sed 's|.*/||')
  url="https://downloads.cursor.com/lab/${latest}/darwin/arm64/agent-cli-package.tar.gz"
  update_simple_sri "cursor-cli" "$file" "$latest" "$url"
}

update_minisim() {
  local file="pkgs/minisim.nix"
  local latest url

  latest=$(gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/okwasniewski/MiniSim/releases/download/v${latest}/MiniSim.app.zip"
  update_simple_sri "minisim" "$file" "$latest" "$url"
}

update_maestro_studio() {
  local file="pkgs/maestro-studio.nix"
  local latest url

  latest=$(gh api repos/mobile-dev-inc/maestro-studio/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/mobile-dev-inc/maestro-studio/releases/download/v${latest}/Maestro-Studio-mac-universal.zip"
  update_simple_sri "maestro-studio" "$file" "$latest" "$url"
}

update_vite_plus() {
  local file="pkgs/vite-plus.nix"
  local latest url

  latest=$(curl -fsSL "https://registry.npmjs.org/@voidzero-dev%2Fvite-plus-cli-darwin-arm64/latest" | jq -r '.version')
  url="https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-darwin-arm64/-/vite-plus-cli-darwin-arm64-${latest}.tgz"
  update_simple_sri "vite-plus" "$file" "$latest" "$url"
}

update_agent_browser() {
  local file="pkgs/agent-browser.nix"
  local latest url

  latest=$(gh api repos/vercel-labs/agent-browser/releases/latest --jq '.tag_name' | sed 's/^v//')
  url="https://github.com/vercel-labs/agent-browser/releases/download/v${latest}/agent-browser-darwin-arm64"
  update_simple_sri "agent-browser" "$file" "$latest" "$url"
}

update_apple_container() {
  local file="pkgs/apple-container.nix"
  local latest url

  latest=$(gh api repos/apple/container/releases/latest --jq '.tag_name')
  url="https://github.com/apple/container/releases/download/${latest}/container-${latest}-installer-signed.pkg"
  update_simple_sri "apple-container" "$file" "$latest" "$url"
}

# The license covers 4.x only, and the public appcast stops at 3.x, so probe the
# download host for the next patch or minor 4.x release until none exists.
update_cleanshot() {
  local file="pkgs/cleanshot.nix"
  local base="https://updates.getcleanshot.com/v3/CleanShot-X-"
  local latest major minor patch

  latest=$(current_version "$file")
  IFS=. read -r major minor patch <<<"$latest"
  patch=${patch:-0}

  while true; do
    if curl -fsIL -o /dev/null "${base}${major}.${minor}.$((patch + 1)).dmg"; then
      patch=$((patch + 1))
      latest="${major}.${minor}.${patch}"
    elif curl -fsIL -o /dev/null "${base}${major}.$((minor + 1)).dmg"; then
      minor=$((minor + 1))
      patch=0
      latest="${major}.${minor}"
    else
      break
    fi
  done

  update_simple_sri "cleanshot" "$file" "$latest" "${base}${latest}.dmg"
}

# Two source builds in one file: openwsman (first version/hash), then wsmancli.
# GitHub's "latest release" for wsmancli is an old one, so take the highest v* tag.
update_wsmancli() {
  local file="pkgs/wsmancli.nix"
  local n repo before latest hash

  for n in 1 2; do
    if [[ $n == 1 ]]; then repo=openwsman; else repo=wsmancli; fi
    before=$(current_version "$file" "$n")
    latest=$(gh api "repos/Openwsman/${repo}/tags" --paginate --jq '.[].name' | sed -n 's/^v\([0-9.]*\)$/\1/p' | sort -V | tail -n 1)
    if [[ "$before" != "$latest" ]]; then
      hash=$(nix flake prefetch --json "github:Openwsman/${repo}/v${latest}" | jq -r '.hash')
      set_nth "$file" version "$n" "$latest"
      set_nth "$file" hash "$n" "$hash"
    fi
    log_status "$repo" "$before" "$latest"
  done
}

update_agent_device() {
  local file="pkgs/agent-device.nix"
  local latest url

  latest=$(curl -fsSL "https://registry.npmjs.org/agent-device/latest" | jq -r '.version')
  url="https://registry.npmjs.org/agent-device/-/agent-device-${latest}.tgz"
  update_simple_sri "agent-device" "$file" "$latest" "$url"
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
    "agent-browser:update_agent_browser"
    "agent-device:update_agent_device"
    "apple-container:update_apple_container"
    "claude-code:update_claude_code"
    "cleanshot:update_cleanshot"
    "codex-cli:update_codex_cli"
    "cursor-cli:update_cursor_cli"
    "minisim:update_minisim"
    "maestro-studio:update_maestro_studio"
    "vite-plus:update_vite_plus"
    "wsmancli:update_wsmancli"
  )
  local failed_steps=()
  local spec name handler status file

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
  require_cmd jq
  require_cmd nix
  require_cmd perl
  require_cmd rg

  repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  cd "$repo_root"

  echo "Updating packages in pkgs/..."

  shopt -s nullglob
  for file in pkgs/*.nix pkgs/*/default.nix; do
    rg -q 'version = "' "$file" || continue
    name=${file#pkgs/}
    name=${name%/default.nix}
    name=${name%.nix}
    if [[ " ${update_specs[*]} " != *" $name:"* ]]; then
      printf '  %-15s not handled by this script; update manually via the pkg-update skill\n' "$name"
    fi
  done

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

    if ! nix build .#darwinConfigurations.personal.system --no-link --option eval-cache false; then
      failed_steps+=("personal verification")
    fi

    if ! nix build .#darwinConfigurations.work.system --no-link --option eval-cache false; then
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
