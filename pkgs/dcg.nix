# dcg (Destructive Command Guard) - prebuilt release binary, not in nixpkgs.
# PreToolUse hook for Claude Code and Codex; config lives in ai-sauce hooks/dcg.toml.
# Update: bump version, then
#   nix hash convert --hash-algo sha256 "$(nix-prefetch-url https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v<version>/dcg-aarch64-apple-darwin.tar.xz)"
{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.13.0";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v${version}/dcg-aarch64-apple-darwin.tar.xz";
      hash = "sha256-bmMiaOGBWgaJ7Wd8GiVPwh8Nd1FRpXgci1+baDgDGGA=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "dcg";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  # The tarball holds a single `dcg` file, no top-level directory.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 dcg $out/bin/dcg
    runHook postInstall
  '';

  meta = {
    description = "Pre-execution hook that blocks destructive shell commands from AI coding agents";
    homepage = "https://github.com/Dicklesworthstone/destructive_command_guard";
    # MIT with a rider excluding OpenAI and Anthropic as licensees.
    license = lib.licenses.mit;
    mainProgram = "dcg";
    platforms = [ "aarch64-darwin" ];
  };
}
