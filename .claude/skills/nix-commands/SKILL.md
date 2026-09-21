---
name: nix-commands
description: Nix operations - search packages, verify builds, and inspect build configuration. Applying the system is human-only in ~/.nix.
allowed-tools: Bash, Read, Grep
---

# Nix Operations

## Search Packages

### Search nixpkgs

```bash
nix search nixpkgs $QUERY --json | jq -r 'to_entries[] | "\(.key): \(.value.description)"' | head -20
```

### Alternative with more detail

```bash
nix-env -qaP ".*$QUERY.*" 2>/dev/null | head -20
```

### Find binary by name

```bash
nix-locate --whole-name --type x "bin/$BINARY" 2>/dev/null | head -5
```

---

## Verify Build Configuration

For build-optimization work, select checks for technologies the project uses.

### 1. Check for Derivation Splitting

```bash
# Look for bun install inside app derivations (anti-pattern)
rg "bun install" flake.nix flake/*.nix 2>/dev/null | rg -v "nodeModules|node-modules"
```

**If found**: Flag as anti-pattern. `bun install` should only be in a dedicated `nodeModules` derivation.

### 2. Check nixpkgs Pin

```bash
rg "nixpkgs.url" flake.nix
```

**Check**: The pin matches the repository's release policy.

### 3. Check CI Configuration

```bash
rg -A5 "nix-installer-action" .github/workflows/*.yml 2>/dev/null | rg "magic-nix-cache|cachix"
```

**Check**: The project's chosen cache is configured.

### 4. Check nix2container Layer Separation

```bash
rg -A10 "buildImage" flake.nix flake/*.nix 2>/dev/null | rg "layers"
```

**Expected**: `layers = [` with runtime deps separated from app code.

### 5. Report relevant findings

```
## Nix Build Optimization Check

### Derivation Splitting
- [ ] nodeModules separate from app derivation
- [ ] bun install only in nodeModules

### Caching
- [ ] nixpkgs pin matches repository policy
- [ ] Chosen cache configured, if applicable

### Container Images
- [ ] nix2container with layer separation
- [ ] Runtime deps in separate layer

### Issues Found
[List any anti-patterns detected]

### Recommended Fixes
[Specific fix for each issue]
```

---

## Darwin Rebuild

### 1. Format Check (treefmt-nix)

```bash
cd ~/.nix
nix fmt -- --fail-on-change
```

### 2. Run flake checks, if defined

```bash
nix flake check
```

### 3. Build Test

```bash
mise run check-personal
mise run check-work
```

Include `mise run check-llm-server` for affected server code or shared dependencies, and the documented sandbox checks for sandbox changes. Direct `nix build` commands require `--no-link`.

### 4. Report build results

Applying configuration is human-only in `~/.nix`.
