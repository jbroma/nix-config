# nix-config

My personal macOS configuration using [Nix](https://nixos.org/), [nix-darwin](https://github.com/LnL7/nix-darwin), and [home-manager](https://github.com/nix-community/home-manager).

## What's included

-   System-level macOS preferences (Finder, keyboard, control center, etc.)
-   Development tools and CLI utilities
-   Shell configuration (zsh, oh-my-posh)
-   Terminal setup (wezterm, zellij)
-   Window management (aerospace, sketchybar)
-   Git, editor configs, and more

## Quick Start

Download and run the setup script:

```bash
curl -fsSL https://raw.githubusercontent.com/jbroma/nix-config/main/scripts/setup.sh -o /tmp/setup.sh && bash /tmp/setup.sh
```

The script will:

1. Install Nix via Determinate Systems installer
2. Clone this repo to `~/.nix`
3. Prompt for configuration details (name, email, system username)
4. Apply the nix-darwin configuration

If the private AI flake input is not accessible yet, apply the matching
bootstrap profile first. After 1Password SSH access is enabled, run the normal
profile:

```bash
sudo darwin-rebuild switch --flake ~/.nix#personal-bootstrap
darwin-rebuild-switch
```

Use `work-bootstrap` instead of `personal-bootstrap` on work machines.

See [SETUP_DETAILS.md](./SETUP_DETAILS.md) for post-installation manual setup steps.

## Usage

The following shell commands are available after setup:

-   `darwin-rebuild-switch`: build and apply the pinned configuration
-   `flake-update`: refresh flake inputs, including nixpkgs and Nix-managed Homebrew taps
-   `darwin-cleanup`: prune the Nix cache

Errors omit full evaluation traces by default. Use `darwin-rebuild-switch --show-trace` when debugging a Nix evaluation failure.

## Updates

| Command | What it updates |
| --- | --- |
| `mise run update` | Flake inputs: Nix packages, Homebrew itself, custom taps, Cursor extensions, and ai-sauce. Run `darwin-rebuild-switch` afterward to apply them. |
| `mise run homebrew-upgrade` | Refreshes official Homebrew metadata and upgrades installed formulae and casks, including nightlies. Custom taps still use their applied Nix revisions. |
| `mise run pkg-update` | Uses the package-update skill for local `pkgs/` pins. The script-only variant covers five packages and lists the rest for manual review. Build and apply afterward. |
| `mise run ai-plugins-update` | Refreshes Claude marketplaces and updates user-installed plugins. Restart Claude afterward. |
| `mise upgrade` | Upgrades mise runtimes within configured version ranges. The shell's `mise install` hook only installs missing versions. |

Cursor's managed extensions, Claude Code CLI, and Vite+ have their own updaters disabled because Nix owns their versions. CleanShot stays on licensed 4.x releases. A successful rebuild does not check upstream for new versions.
