{
  ai,
  ...
}:

{
  home.sessionVariables = {
    CODEX_HOME = "$HOME/.codex";
  };

  # Symlinks from ai submodule
  home.file.".codex/AGENTS.md".source = "${ai}/AGENTS.md";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/rules.toml";
}
