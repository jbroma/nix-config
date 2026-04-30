#!/usr/bin/env bash

set -euo pipefail

if /run/current-system/sw/bin/darwin-rebuild switch --flake "${1:?usage: rebuild-and-switch.sh <flake-ref>}"; then
  exit 0
fi

echo "Initial rebuild failed; retrying once with refreshed flake sources..." >&2
exec /run/current-system/sw/bin/darwin-rebuild switch --refresh --flake "${1:?usage: rebuild-and-switch.sh <flake-ref>}"
