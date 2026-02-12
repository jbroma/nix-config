---
name: pkg-update
description: Use when updating custom package derivations in pkgs/ and you need to refresh versions, hashes, and nix-darwin verification without applying the system.
---

# Package Update Skill

Update local packages in `~/.nix/pkgs/`.

## Guardrails

- Never run `mise run switch` during package updates.
- Verify with `mise run check` before finishing.
- For full overlay validation, build with `--no-link` only.
- Edit only relevant files in `pkgs/`.

## Workflow

1. Inspect current package metadata:
   - `rg -n "pname =|name =|version =|url =|hash =|sha256 =" pkgs/*.nix`
2. Check latest upstream versions using the table below.
3. Update `version` and any URL segments tied to version.
4. Prefetch new hash:
   - SRI: `sri=$(nix store prefetch-file --json "$url" | jq -r '.hash')`
   - nix32: `nix hash convert --from sri --to nix32 "$sri"`
   - hex: `nix hash convert --from sri --to base16 "$sri"`
5. Verify:
   - `mise run check`
   - `nix build .#darwinConfigurations.personal.system --no-link`
   - `nix build .#darwinConfigurations.work.system --no-link` (if touching shared packages)

## Package Reference

| Package | Upstream check | Hash format in file | Notes |
|---------|----------------|---------------------|-------|
| `android-studio` | `https://developer.android.com/studio/releases` (manual) | hex (`sha256`) | Redirector URLs can return 302 for invalid versions. Verify real DMG and keep app name `Android Studio.app` (not preview builds). |
| `claude-code` | `v=$(curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" \| jq -r '.version')` then `curl -fsI "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${v}/darwin-arm64/claude"` | SRI (`hash`) | Package is native binary (not npm install). Treat npm version as candidate and validate binary URL exists. |
| `claude-island` | `gh api repos/farouqaldori/claude-island/releases/latest --jq '.tag_name' \| sed 's/^v//'` | nix32 (`sha256`) | DMG filename uses `ClaudeIsland-${version}.dmg`. |
| `cleanshot-x` | `https://cleanshot.com/changelog` (manual) | hex (`sha256`) | Download URL pattern: `.../CleanShot-X-${version}.dmg`. |
| `codex-app` | Static URL only: `https://persistent.oaistatic.com/codex-app-prod/Codex.dmg` | SRI (`hash`) | Prefetch hash, then build. Derivation validates `CFBundleShortVersionString` and fails with expected version to set. |
| `codex-cli` | `gh api repos/openai/codex/releases/latest --jq '.tag_name' \| sed 's/^rust-v//'` | SRI (`hash`) | URL tag prefix is `rust-v${version}`. |
| `dcg` | `gh api repos/Dicklesworthstone/destructive_command_guard/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Tarball URL uses `v${version}` tag. |
| `handy` | `gh api repos/cjpais/Handy/releases/latest --jq '.tag_name' \| sed 's/^v//'` | nix32 (`sha256`) | DMG filename: `Handy_${version}_aarch64.dmg`. |
| `minisim` | `gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' \| sed 's/^v//'` | hex (`sha256`) | ZIP filename: `MiniSim.app.zip`. |
| `worktrunk` | `gh api repos/max-sixty/worktrunk/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Tarball URL uses `worktrunk-aarch64-apple-darwin.tar.xz`. |
| `zed-editor` | `gh api repos/zed-industries/zed/releases/latest --jq '.tag_name' \| sed 's/^v//'` | nix32 (`sha256`) | Keep `version` and release URL (`v${version}` + `Zed-aarch64.dmg`) aligned. |

## Gotchas

- Build targets are overlays. Do not use `.#<package>`; validate via darwin config checks/builds.
- Match existing hash format in each file (`hash` SRI vs `sha256` nix32/hex).
- `curlie` defaults to POST and can break API checks; use `curl` for release/version lookups.
- After touching many packages, re-list package files with `rg --files pkgs` and ensure all changed files were intentionally updated.
