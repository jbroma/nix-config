---
name: pkg-update
description: Update local Nix packages in pkgs/ - fetches latest versions, updates hashes, verifies builds
allowed-tools: Bash, Read, Edit, Grep, Glob, WebFetch
---

# Package Update Skill

Updates local packages in `~/.nix/pkgs/`. Each package has a different source type requiring specific update strategies.

**IMPORTANT: Never run `mise run switch` or `darwin-rebuild switch`. Only build and verify - user always reloads on their own.**

## Workflow

1. **Identify package** - Read the .nix file to understand source type
2. **Find latest version** - Use appropriate method for source type
3. **Update version** - Edit version string in the file
4. **Prefetch hash** - Use `nix-prefetch-url` or `nix-hash` to get new hash
5. **Verify build** - Run `nix build .#<package>` to test
6. **Done** - Report success, user will rebuild system themselves

## Source Types

### GitHub Releases

Pattern: `fetchurl { url = "https://github.com/{owner}/{repo}/releases/download/v${version}/..." }`

```bash
# Get latest release version
gh api repos/{owner}/{repo}/releases/latest --jq '.tag_name' | sed 's/^v//'

# Prefetch new hash (for .dmg files)
nix-prefetch-url --type sha256 "https://github.com/{owner}/{repo}/releases/download/v{NEW_VERSION}/{filename}"
```

### Google Storage (claude-code)

Pattern: `url = "https://storage.googleapis.com/.../${version}/darwin-arm64/claude"`

```bash
# Check manifest for latest version
curlie -s "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/versions/manifest.json" | jq -r '.latestVersion'

# Prefetch new binary
nix-prefetch-url "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/{VERSION}/darwin-arm64/claude"
```

### Direct URL with version

Pattern: `fetchurl { url = "https://example.com/path/${version}/file.dmg" }`

```bash
# Prefetch after determining new version manually or from webpage
nix-prefetch-url "https://example.com/path/{NEW_VERSION}/file.dmg"
```

### Archive with hash (sha256- format)

Modern Nix uses SRI hashes. Convert from base32:

```bash
# If nix-prefetch-url gives base32, convert to SRI:
nix hash convert --hash-algo sha256 --to sri {BASE32_HASH}
```

## Package Reference

| Package | Source Type | Version Check |
|---------|-------------|---------------|
| claude-code | Google Storage | `curlie` manifest.json |
| claude-island | GitHub releases | `gh api` |
| android-studio | Android redirect | Manual check |
| cleanshot-x | Direct URL | Manual check |
| minisim | GitHub releases | `gh api` |
| handy | GitHub releases | `gh api` |

## Update Steps (Detailed)

### 1. Read current package

```bash
bat ~/.nix/pkgs/{package}.nix
```

### 2. Extract current version

```bash
rg "version\s*=" ~/.nix/pkgs/{package}.nix
```

### 3. Check for updates (GitHub example)

```bash
gh api repos/{owner}/{repo}/releases/latest --jq '.tag_name'
```

### 4. Prefetch new hash

```bash
# For standard fetchurl sources
nix-prefetch-url --type sha256 "{NEW_URL}"

# Convert to SRI if needed (hash = "sha256-...")
nix hash convert --hash-algo sha256 --to sri {BASE32_HASH}
```

### 5. Edit the file

Update `version` and `hash`/`sha256` values in the .nix file.

### 6. Verify build

```bash
cd ~/.nix
nix build .#<package> --print-build-logs
```

### 7. Report completion

Tell user the update is complete and they can rebuild when ready.

**DO NOT run `darwin-rebuild switch` or `mise run switch` - user handles this.**

## Troubleshooting

### Hash mismatch

If build fails with hash mismatch, the error shows expected vs got. Use the "got" hash.

### Unfree package error

Ensure package is in `allowUnfreePredicate` list in `flake.nix`.

### Build sandbox issues

For packages needing network access during build, check `__noChroot` or use `requireFile`.
