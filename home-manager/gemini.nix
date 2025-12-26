{
  config,
  pkgs,
  ...
}:

{
  # Gemini CLI configuration
  # Symlinks handled by ai/nix/integration.nix

  home.packages = [
    # pkgs.gemini-cli  # Uncomment when available in nixpkgs
  ];
}
