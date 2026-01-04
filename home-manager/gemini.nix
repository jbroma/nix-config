{
  config,
  ...
}:

let
  # Use absolute path to avoid nix flake git tracking issues
  aiDir = "${config.home.homeDirectory}/.nix/ai";
in
{
  # Gemini CLI configuration
  # Symlinks handled by ai/nix/integration.nix

  # Gemini CLI symlinks
  home.file.".gemini/GEMINI.md".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/AGENTS.md";
  home.file.".gemini/rules".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/rules";

  home.packages = [
    # pkgs.gemini-cli  # Uncomment when available in nixpkgs
  ];
}
