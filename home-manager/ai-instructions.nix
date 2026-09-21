# Shared user-level instructions for every AI tool: ai-sauce CORE.md with the
# skills that must always apply appended, so no tool has to decide to load them.
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

  # UserPromptSubmit hook shared by Claude Code and Codex. It keeps pstack's
  # poteto-mode on across turns, which Cursor does natively with `mode: true`.
  options.ai.pstackModeHook = lib.mkOption {
    type = lib.types.path;
    description = "Wrapper that runs ai-sauce's pstack/mode-hook.sh with its own PATH";
    default = pkgs.writeShellScript "pstack-mode-hook" ''
      export PATH=${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnused
          pkgs.jq
        ]
      }
      exec ${pkgs.bash}/bin/bash ${ai}/pstack/mode-hook.sh ${ai}/skills/poteto-mode/SKILL.md
    '';
  };
}
