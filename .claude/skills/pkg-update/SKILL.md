---
name: pkg-update
description: Update local Nix packages in pkgs/ - fetches latest versions, updates hashes, verifies builds
allowed-tools: Bash, Read, Edit, Grep, Glob, WebFetch, WebSearch
---

# Package Update Skill

Updates local packages in `~/.nix/pkgs/`.

**Never run `mise run switch` - only build and verify.**

## Package Reference

| Package | Source Type | Version Check |
|---------|-------------|---------------|
| claude-code | npm registry | `curl -s "https://registry.npmjs.org/@anthropic-ai/claude-code/latest" \| jq -r '.version'` |
| minisim | GitHub releases | `gh api repos/okwasniewski/MiniSim/releases/latest --jq '.tag_name'` |
| handy | GitHub releases | `gh api repos/cjpais/Handy/releases/latest --jq '.tag_name'` |
| cleanshot-x | Direct URL | WebFetch `https://cleanshot.com/changelog` |
| android-studio | Google redirector | WebFetch `https://developer.android.com/studio/releases` + verify |
| codex-app | Static URL | `nix-prefetch-url` the URL, compare hash. Version extracted from `Info.plist` post-build (build fails on mismatch) |

## Workflow

1. Read all `pkgs/*.nix` files to get current versions
2. Run version checks in parallel (first 4 packages above)
3. For packages needing update: `nix-prefetch-url`, edit file, verify build
4. Build: `nix build .#darwinConfigurations.personal.system --no-link`

## Gotchas

- **claude-code**: Old manifest.json URL is dead. Use npm registry.
- **android-studio**: HEAD returns 302 even for non-existent versions. Must verify actual download works. Canary builds have "Android Studio Preview.app" - reject these. The releases page doesn't expose version numbers reliably via WebFetch - if current URL works, keep it.
- **Build verification**: Packages are overlays, use `.#darwinConfigurations.personal.system` not `.#<package>`
- **Hash format**: Match existing format in file (base32, hex, or SRI). To convert nix32 → hex: `nix hash convert --from nix32 --to base16 --hash-algo sha256 "<hash>"`
- **curl not curlie**: curlie defaults to POST which breaks APIs
