---
name: pkg-update
description: Use when updating custom package derivations in pkgs/ and you need to refresh versions, hashes, and nix-darwin verification without applying the system.
---

# Package Update Skill

Update local packages in `~/.nix/pkgs/`.

## Guardrails

- Never run `mise run switch` during package updates.
- Verify with `nix build ... --no-link` before finishing (`mise run check` can fail when `darwin-rebuild check` requires root).
- For full overlay validation, build with `--no-link` only.
- Edit only relevant files in `pkgs/`.
- Prefer the repo script first: `mise run pkg-update-script` or `./scripts/pkg-update.sh`.

## Workflow

1. Run the repo updater:
   - `mise run pkg-update-script`
2. Inspect current package metadata when debugging or handling an edge case:
   - `rg -n "pname =|name =|version =|url =|hash =|sha256 =" pkgs/*.nix`
3. For manual fixes or script maintenance, check latest upstream versions using the table below.
4. Update `version` and any URL segments tied to version.
5. Prefetch new hash:
   - SRI: `sri=$(nix store prefetch-file --json "$url" | jq -r '.hash')`
   - nix32: `nix hash convert --from sri --to nix32 "$sri"`
   - hex: `nix hash convert --from sri --to base16 "$sri"`
6. Verify:
   - Skip `mise run check` for package updates; use darwin `nix build` targets directly.
   - `nix build .#darwinConfigurations.personal.system --no-link`
   - `nix build .#darwinConfigurations.work.system --no-link` (if touching shared packages)

## Package Reference

| Package | Upstream check | Hash format in file | Notes |
|---------|----------------|---------------------|-------|
| `android-studio` | `https://developer.android.com/studio/releases` (manual) | hex (`sha256`) | Redirector URLs can return 302 for invalid versions. Verify real DMG and keep app name `Android Studio.app` (not preview builds). |
| `claude-code` | `v=$(curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" \| jq -r '.version')` then `curl -fsI "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${v}/darwin-arm64/claude"` | SRI (`hash`) | Package is native binary (not npm install). Treat npm version as candidate and validate binary URL exists. |
| `claude-desktop` | `curl -fsSL "https://downloads.claude.ai/releases/darwin/universal/RELEASES.json" \| jq` | SRI (`hash`) | Read `.currentRelease` for the version and `.releases[].updateTo.url` for the exact versioned zip. Prefer `bash scripts/update-claude-desktop.sh` to keep `version`, `url`, and `hash` aligned together. |
| `cleanshot-x` | `https://cleanshot.com/changelog` (manual) | hex (`sha256`) | Download URL pattern: `.../CleanShot-X-${version}.dmg`. |
| `codex-app` | Static URL only. Use cache-busting for checks/prefetch: `u="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg?ts=$(date +%s)"` then `nix store prefetch-file --json --refresh "$u"` | SRI (`hash`) | CDN can serve stale blob at the bare URL. Keep derivation URL static, but use cache-busting URL for version/hash discovery. Derivation validates `CFBundleShortVersionString` and fails with expected version to set. |
| `codex-cli` | `gh api repos/openai/codex/releases/latest --jq '.tag_name' \| sed 's/^rust-v//'` | SRI (`hash`) | URL tag prefix is `rust-v${version}`. |
| `minisim` | `gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name' \| sed 's/^v//'` | hex (`sha256`) | ZIP filename: `MiniSim.app.zip`. |
| `spotify` | `nix store prefetch-file --json --refresh "https://download.scdn.co/SpotifyARM64.dmg"` then read `Spotify.app/Contents/Info.plist` `CFBundleVersion` | SRI (`hash`) | CDN URL is mutable. Keep the derivation URL static, but use `--refresh` for version/hash discovery and hash-pin the exact artifact. |
| `worktrunk` | `gh api repos/max-sixty/worktrunk/releases/latest --jq '.tag_name' \| sed 's/^v//'` | SRI (`hash`) | Tarball URL uses `worktrunk-aarch64-apple-darwin.tar.xz`. |
| `zed-editor` | `gh api repos/zed-industries/zed/releases/latest --jq '.tag_name' \| sed 's/^v//'` | nix32 (`sha256`) | Keep `version` and release URL (`v${version}` + `Zed-aarch64.dmg`) aligned. |

## Gotchas

- Build targets are overlays. Do not use `.#<package>`; validate via darwin config checks/builds.
- Match existing hash format in each file (`hash` SRI vs `sha256` nix32/hex).
- `curlie` defaults to POST and can break API checks; use `curl` for release/version lookups.
- The script checks the current pinned version and validates the upstream artifact URL before doing expensive prefetch/hash work.
- If you add a brand-new package file and want to target-build it before staging or committing, use a `path:` flake reference so Nix sees untracked files.
- For `codex-app`, always discover hash/version from a cache-busted URL (`?ts=...`) to avoid stale CDN edge cache.
- `codex-app` and `spotify` are exceptions to the cheap path: the version is hidden inside the app bundle, so the script still has to fetch the DMG after validating the URL exists.
- After touching many packages, re-list package files with `rg --files pkgs` and ensure all changed files were intentionally updated.
