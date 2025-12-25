# nix-config

My personal macOS configuration using [Nix](https://nixos.org/), [nix-darwin](https://github.com/LnL7/nix-darwin), and [home-manager](https://github.com/nix-community/home-manager).

## What's included

-   System-level macOS preferences (Finder, keyboard, control center, etc.)
-   Development tools and CLI utilities
-   Shell configuration (zsh, oh-my-posh)
-   Terminal setup (ghostty, zellij)
-   Window management (aerospace, sketchybar)
-   Git, editor configs, and more

## Quick Start

Run the setup script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/jbroma/nix-config/main/scripts/setup.sh | bash
```

The script will:

1. Install Nix via Determinate Systems installer
2. Clone this repo to `~/.nix`
3. Prompt for configuration details (name, email, system username)
4. Apply the nix-darwin configuration

## Usage

The following shell commands are available after setup:

-   `darwin-rebuild-switch` — reload the configuration after making changes
-   `flake-update` — update to newest package versions
-   `darwin-cleanup` — prune the nix cache
