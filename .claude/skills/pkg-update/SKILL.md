---
name: pkg-update
description: Update local Nix packages in pkgs/ - fetches latest versions, updates hashes, verifies builds without applying the system
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Package Update Skill

Updates local packages in `~/.nix/pkgs/`. Build and verify only; never apply the system.

## Workflow

1. Run the repo updater first: `mise run pkg-update-script` (`./scripts/pkg-update.sh`). It covers claude-code, codex-cli, maestro-studio, minisim and vite-plus, and skips a package when the pinned version already matches upstream.
2. For the packages the script does not cover, or when it fails, update by hand: bump `version` and any URL segment tied to it, then prefetch the hash: `nix store prefetch-file --json "$url" | jq -r '.hash'`
3. Verify both configs:
   - `nix build .#darwinConfigurations.personal.system --no-link`
   - `nix build .#darwinConfigurations.work.system --no-link`

## Package Reference

| Package | Upstream check | Hash format | Notes |
|---------|----------------|-------------|-------|
| `agent-browser` | `gh api repos/vercel-labs/agent-browser/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Manual. Prebuilt `agent-browser-darwin-arm64` release asset. |
| `agent-device` | `curl -fsSL https://registry.npmjs.org/agent-device/latest \| jq -r '.version'` | SRI (`hash`, `npmDeps.hash`) | Manual. Regenerate `package-lock.json` as described in the file header, then `nix run nixpkgs#prefetch-npm-deps -- pkgs/agent-device/package-lock.json` for `npmDeps.hash`. |
| `apple-container` | `gh api repos/apple/container/releases/latest --jq '.tag_name'` | SRI (`hash`) | Manual. `overrideAttrs` of nixpkgs `container` onto the newer signed installer `.pkg`; bump `version`, prefetch the `container-${version}-installer-signed.pkg` URL. After a bump, `container system stop && container system start` on the machine, since a running apiserver keeps serving from the old store path. The file can go once nixpkgs' `container` is >= 1.2.0 (the 1.2.0 fixes for CVE-2026-64777 and CVE-2026-64786 matter for the sandbox), together with its consumer `home-manager/llm.nix` switching to `pkgs.container`. |
| `claude-code` | `curl -fsSL https://registry.npmjs.org/@anthropic-ai/claude-code/latest \| jq -r '.version'` | SRI (`hash`) | Script. Native binary from the GCS bucket, npm version is only the candidate; the script checks the binary URL exists. |
| `codex-cli` | `gh api repos/openai/codex/releases/latest --jq '.tag_name' \| sed 's/^rust-v//'` | SRI (`hash`) | Script. Release tag is `rust-v${version}`; asset is `codex-package-aarch64-apple-darwin.tar.gz`. |
| `maestro-studio` | `gh api repos/mobile-dev-inc/maestro-studio/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Script. Asset is `Maestro-Studio-mac-universal.zip`. Build fails with the real version if `Info.plist` disagrees. |
| `minisim` | `gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Script. Asset is `MiniSim.app.zip`. |
| `vite-plus` | `curl -fsSL 'https://registry.npmjs.org/@voidzero-dev%2Fvite-plus-cli-darwin-arm64/latest' \| jq -r '.version'` | SRI (`hash`) | Script. Platform tarball from npm; `home-manager/vite-plus.nix` bootstraps the matching global install on switch. |
| `wsmancli` | `gh api repos/Openwsman/wsmancli/tags --jq '.[0].name'` (and `Openwsman/openwsman` for the bundled lib) | SRI (`hash`) | Manual, rarely changes. Built from source; two versions in one file. |

## Gotchas

- Packages are overlays: build `.#darwinConfigurations.<profile>.system`, not `.#<package>`.
- Use `curl`, not `curlie`, for version lookups (curlie defaults to POST).
- A brand-new, untracked package file needs a `path:` flake reference (or `git add`) before Nix sees it.
