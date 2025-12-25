#!/bin/bash

# -e: exit on error
# -u: error on undefined vars
# -o pipefail: fail on pipe errors
set -euo pipefail

# Choose configuration variant
read -p "Configuration (personal/work): " CONFIG
[[ "$CONFIG" =~ ^(personal|work)$ ]] || { echo "Invalid choice"; exit 1; }

# -x: print commands before execution
set -x

# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nixpkgs#git clone https://github.com/jbroma/nix-config.git ~/.nix

# Delete nix.conf since it's managed by nix-darwin
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin

# Hide Nix Store from root
sudo chflags hidden /nix

/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.nix#$CONFIG
