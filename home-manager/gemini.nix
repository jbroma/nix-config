{
  ai,
  ...
}:

{
  # Gemini CLI symlinks
  home.file.".gemini/GEMINI.md".source = "${ai}/AGENTS.md";
  home.file.".gemini/rules".source = "${ai}/rules";

  home.packages = [
    # pkgs.gemini-cli  # Uncomment when available in nixpkgs
  ];
}
