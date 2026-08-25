# Shared user-level instructions for every AI tool: ai-sauce CORE.md with the
# skills that must always apply appended, so no tool has to decide to load them.
{ ai, lib, ... }:

let
  core = builtins.readFile "${ai}/CORE.md";

  # Drop the YAML frontmatter from a SKILL.md, keep the body.
  skillBody =
    name:
    let
      parts = lib.splitString "---\n" (builtins.readFile "${ai}/skills/${name}/SKILL.md");
    in
    lib.concatStringsSep "---\n" (lib.drop 2 parts);

  alwaysApply = [
    "unslop"
    "principle-minimize-reader-load"
  ];
in
{
  options.ai.instructions = lib.mkOption {
    type = lib.types.str;
    description = "CORE.md plus the always-apply skills, rendered as CLAUDE.md / AGENTS.md / Cursor rules";
    default = lib.concatStringsSep "\n" ([ core ] ++ map skillBody alwaysApply);
  };
}
