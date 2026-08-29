# LLM server role: Ollama on the LAN, SSH in, stays awake on AC. Enabled per machine by
# `llmServer = true;` in user.nix (local, not committed). Vault note: Homelab/LLM Server.md
# Lid closed with no display attached needs `sudo pmset -a disablesleep 1` (also disables
# lid-close sleep on battery, resets at reboot); left manual on purpose.
{ lib, llm, ... }:

{
  config = lib.mkIf llm.server {
    # Ollama itself: Homebrew formula (MLX backend); the launchd agent lives in home-manager/llm.nix.
    homebrew.brews = [ "ollama" ];

    # nix-darwin enables sshd via launchctl; `systemsetup -setremotelogin` would need Full Disk Access.
    # Keys only: put the client's public key in ~/.ssh/authorized_keys before the first rebuild.
    services.openssh = {
      enable = true;
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
      '';
    };

    # On AC never idle-sleep; screen off after 10 min. Battery keeps macOS defaults.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/pmset -c sleep 0 displaysleep 10 disksleep 0
    '';
  };
}
