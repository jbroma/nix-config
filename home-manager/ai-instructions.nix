# Shared user-level config for every AI tool: ai-sauce CORE.md with the skills
# that must always apply appended, and the PreToolUse hook that Claude Code and
# Codex both load.
{
  ai,
  lib,
  pkgs,
  ...
}:

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

  options.ai.hooks = lib.mkOption {
    type = lib.types.attrs;
    description = "ai-sauce hooks/definitions.json with $DCG_BIN resolved to the nix store dcg binary";
    # fromJSON rejects strings that reference the store, so substitute after parsing.
    default =
      let
        resolve =
          v:
          if builtins.isString v then
            builtins.replaceStrings [ "$DCG_BIN" ] [ (lib.getExe pkgs.dcg) ] v
          else if builtins.isList v then
            map resolve v
          else if builtins.isAttrs v then
            lib.mapAttrs (_: resolve) v
          else
            v;
      in
      resolve (builtins.fromJSON (builtins.readFile "${ai}/hooks/definitions.json"));
  };
}
