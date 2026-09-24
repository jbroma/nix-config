# Cursor CLI, Cursor's coding agent for the terminal
# https://cursor.com/cli
# nixpkgs trails Cursor's releases by weeks; this repacks the build cursor.com/install ships.
# Its self-updater is off through the "static" channel set in home-manager/cursor.nix.
# The overlay replaces cursor-cli itself, so the nixpkgs derivation is loaded by path.
{
  path,
  callPackage,
  fetchurl,
}:
(callPackage "${path}/pkgs/by-name/cu/cursor-cli/package.nix" { }).overrideAttrs (
  finalAttrs: prev: {
    version = "2026.09.23-86fc751";
    src = fetchurl {
      url = "https://downloads.cursor.com/lab/${finalAttrs.version}/darwin/arm64/agent-cli-package.tar.gz";
      hash = "sha256-+j/hPVWJxYb/EyokwW7qlvuO/eiK/e/dzRHYD6GZ86U=";
    };
    # nixpkgs' sources and updateScript describe its own older build.
    passthru = removeAttrs prev.passthru [
      "sources"
      "updateScript"
    ];
    # The installer links both names; Cursor's docs use `agent`.
    postInstall = (prev.postInstall or "") + ''
      ln -s $out/share/cursor-agent/cursor-agent $out/bin/agent
    '';
  }
)
