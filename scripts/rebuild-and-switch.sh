#!/usr/bin/env bash

set -euo pipefail

ulimit -n 4096

flake_ref=${1:?usage: rebuild-and-switch.sh <flake-ref> [darwin-rebuild options]}
shift

# eval-cache off: user.nix is skip-worktree, so its edits do not change the flake fingerprint and
# a cached evaluation could activate a system built for the old role. (darwin-rebuild forwards
# --option but does not know --no-eval-cache.)
if /run/current-system/sw/bin/darwin-rebuild switch --option eval-cache false --option show-trace false --flake "$flake_ref" "$@"; then
  exit 0
fi

echo "Initial rebuild failed; retrying once with refreshed flake sources..." >&2
exec /run/current-system/sw/bin/darwin-rebuild switch --option eval-cache false --option show-trace false --refresh --flake "$flake_ref" "$@"
