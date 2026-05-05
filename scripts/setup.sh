#!/bin/bash

# -e: exit on error
# -u: error on undefined vars
# -o pipefail: fail on pipe errors
set -euo pipefail

# Choose configuration variant
CURRENT_CONFIG="personal"
read -p "Configuration [personal/work]($CURRENT_CONFIG): " SETUP_CONFIG
SETUP_CONFIG="${SETUP_CONFIG:-$CURRENT_CONFIG}"

# Enter username
CURRENT_USER=$(whoami)
read -p "Username ($CURRENT_USER): " SETUP_USERNAME
SETUP_USERNAME="${SETUP_USERNAME:-$CURRENT_USER}"

# Enter name and email for git
read -p "Name: " SETUP_NAME
read -p "Email: " SETUP_EMAIL

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

SETUP_FLAKE_CONFIG="$SETUP_CONFIG"
AI_INPUT_ARGS=()

if ! GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new" \
  /nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nixpkgs#git -- \
  ls-remote git@github.com:jbroma/ai-sauce.git HEAD >/dev/null 2>&1; then
  BOOTSTRAP_AI_INPUT="$HOME/.nix/.bootstrap-ai-input"
  mkdir -p "$BOOTSTRAP_AI_INPUT"
  BOOTSTRAP_AI_INPUT="$(cd "$BOOTSTRAP_AI_INPUT" && pwd -P)"
  SETUP_FLAKE_CONFIG="$SETUP_CONFIG-bootstrap"
  AI_INPUT_ARGS=(
    --override-input ai "path:$BOOTSTRAP_AI_INPUT"
    --no-write-lock-file
  )
  echo "Private AI flake input is not accessible yet."
  echo "Activating $SETUP_FLAKE_CONFIG without AI tool config."
  echo "After 1Password SSH access works, run: darwin-rebuild-switch"
fi

# Apply configuration
/nix/var/nix/profiles/default/bin/nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake "$HOME/.nix#$SETUP_FLAKE_CONFIG" "${AI_INPUT_ARGS[@]}"
