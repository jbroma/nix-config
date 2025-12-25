#!/bin/bash

# -e: exit on error
# -u: error on undefined vars
# -o pipefail: fail on pipe errors
set -euo pipefail

# Choose configuration variant
CURRENT_CONFIG="personal"
read -p "Configuration [personal/work]($CURRENT_CONFIG): " SETUP_CONFIG < /dev/tty
SETUP_CONFIG="${SETUP_CONFIG:-$CURRENT_CONFIG}"

# Enter username
CURRENT_USER=$(whoami)
read -p "Username ($CURRENT_USER): " SETUP_USERNAME < /dev/tty
SETUP_USERNAME="${SETUP_USERNAME:-$CURRENT_USER}"

# Enter name and email for git
read -p "Name: " SETUP_NAME < /dev/tty
read -p "Email: " SETUP_EMAIL < /dev/tty

# -x: print commands before execution
set -x

# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nixpkgs#git clone https://github.com/jbroma/nix-config.git ~/.nix

# Skip tracking user.nix changes from git
git -C ~/.nix update-index --skip-worktree user.nix

# Create user.nix
cat >| ~/.nix/user.nix << EOF
{
  name = "$SETUP_NAME";
  email = "$SETUP_EMAIL";
  username = "$SETUP_USERNAME";
}
EOF

# Delete nix.conf since it's managed by nix-darwin
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin

# Hide Nix Store from root
sudo chflags hidden /nix

# Apply configuration
/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.nix#$SETUP_CONFIG
