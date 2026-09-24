---
name: pkg-update
description: Update local Nix packages in pkgs/ - fetches latest versions, updates hashes, verifies builds without applying the system
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Package Update Skill

Updates local packages in `~/.nix/pkgs/`. Build and verify only; never apply the system.

## Workflow

1. Run the repo updater first: `mise run pkg-update-script` (`./scripts/pkg-update.sh`). It covers every package in `pkgs/` except `agent-sandbox`, and skips a package when the pinned version already matches upstream.
2. For the packages the script does not cover, or when it fails, update by hand: bump `version` and any URL segment tied to it, then prefetch the hash: `nix store prefetch-file --json "$url" | jq -r '.hash'`
3. Verify both configs:
   - `mise run check-personal`
   - `mise run check-work`

## Package Reference

| Package | Upstream check | Hash format | Notes |
|---------|----------------|-------------|-------|
| `agent-browser` | `gh api repos/vercel-labs/agent-browser/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Script. Prebuilt `agent-browser-darwin-arm64` release asset. |
| `agent-device` | `curl -fsSL https://registry.npmjs.org/agent-device/latest \| jq -r '.version'` | SRI (`hash`) | Script. The npm tarball bundles its dependencies since 0.21, so it is unpacked and wrapped with node. If a release adds runtime `dependencies` again, it needs `buildNpmPackage` and a generated lockfile. |
| `apple-container` | `gh api repos/apple/container/releases/latest --jq '.tag_name'` | SRI (`hash`) | Script. `overrideAttrs` of nixpkgs `container` onto the newer signed installer `.pkg`; bump `version`, prefetch the `container-${version}-installer-signed.pkg` URL. A running apiserver keeps serving from the old store path; the `restartContainerSystem` activation in `home-manager/agent-sandbox.nix` restarts it on switch, or warns when containers are running. The file can go once nixpkgs' `container` is >= 1.2.0 (the 1.2.0 fixes for CVE-2026-64777 and CVE-2026-64786 matter for the sandbox), together with its consumer `home-manager/llm.nix` switching to `pkgs.container`. |
| `claude-code` | `curl -fsSL https://registry.npmjs.org/@anthropic-ai/claude-code/latest \| jq -r '.version'` | SRI (`hash`) | Script. Native binary from the GCS bucket, npm version is only the candidate; the script checks the binary URL exists. |
| `cleanshot` | Probe `https://updates.getcleanshot.com/v3/CleanShot-X-<version>.dmg` for the next 4.x patch or minor | SRI (`hash`) | Script. The license covers 4.x only; the script never leaves the major version. The public appcast stops at 3.x. |
| `codex-cli` | `gh api repos/openai/codex/releases/latest --jq '.tag_name' \| sed 's/^rust-v//'` | SRI (`hash`) | Script. Release tag is `rust-v${version}`; asset is `codex-package-aarch64-apple-darwin.tar.gz`. |
| `cursor-cli` | `curl -fsSL https://cursor.com/install \| rg -o -m1 'downloads\.cursor\.com/lab/[^/]+' \| sed 's\|.*/\|\|'` | SRI (`hash`) | Script. `overrideAttrs` of the nixpkgs derivation onto `agent-cli-package.tar.gz` for `darwin/arm64`. Its self-updater stays off through `channel = "static"` in `~/.cursor/cli-config.json` (`home-manager/cursor.nix`). |
| `maestro-studio` | `gh api repos/mobile-dev-inc/maestro-studio/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Script. Asset is `Maestro-Studio-mac-universal.zip`. Build fails with the real version if `Info.plist` disagrees. |
| `minisim` | `gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Script. Asset is `MiniSim.app.zip`. |
| `vite-plus` | `curl -fsSL 'https://registry.npmjs.org/@voidzero-dev%2Fvite-plus-cli-darwin-arm64/latest' \| jq -r '.version'` | SRI (`hash`) | Script. Platform tarball from npm; `home-manager/vite-plus.nix` bootstraps the matching global install on switch. |
| `wsmancli` | Highest `v*` tag of `Openwsman/wsmancli` and `Openwsman/openwsman` | SRI (`hash`) | Script. Built from source; two versions in one file (openwsman first). Hashes come from `nix flake prefetch github:...`, which matches `fetchFromGitHub`. |

## Gotchas

- Packages are overlays: build `.#darwinConfigurations.<profile>.system`, not `.#<package>`.
- Use `curl`, not `curlie`, for version lookups (curlie defaults to POST).
- A brand-new, untracked package file needs a `path:` flake reference (or `git add`) before Nix sees it.
