#!/bin/bash

# -e: exit on error
# -u: error on undefined vars
# -o pipefail: fail on pipe errors
set -euo pipefail

# Choose configuration variant
CURRENT_CONFIG="personal"
read -p "Configuration [personal/work]($CURRENT_CONFIG): " CONFIG
CONFIG="${CONFIG:-$CURRENT_CONFIG}"

# Enter username
CURRENT_USER=$(whoami)
read -p "Username ($CURRENT_USER): " USERNAME
USERNAME="${USERNAME:-$CURRENT_USER}"

# -x: print commands before execution
set -x

# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nixpkgs#git clone https://github.com/jbroma/nix-config.git ~/.nix

# Create user.nix with the username
cat > ~/.nix/user.nix << EOF
{
  username = "$USERNAME";
}
EOF

# Delete nix.conf since it's managed by nix-darwin
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin

# Hide Nix Store from root
sudo chflags hidden /nix

# Apply configuration
/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.nix#$CONFIG
