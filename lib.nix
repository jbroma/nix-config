# Custom utility functions for this flake
{
  # Parse JSONC (JSON with comments) by stripping // comments
  fromJSONC =
    jsonc:
    let
      parts = builtins.split "//[^\n]*" jsonc;
      clean = builtins.concatStringsSep "" (builtins.filter builtins.isString parts);
    in
    builtins.fromJSON clean;
}
