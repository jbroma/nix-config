# Worktrunk - Git worktree management CLI
# https://github.com/max-sixty/worktrunk
{
  lib,
  stdenv,
  fetchurl,
  xz,
}:
let
  version = "0.25.0";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/max-sixty/worktrunk/releases/download/v${version}/worktrunk-aarch64-apple-darwin.tar.xz";
      hash = "sha256-Uqt6JpkBryCDhrfHTwtBBlNuCm4jsRV5BSYMU5Qr5Iw=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "worktrunk";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  nativeBuildInputs = [ xz ];

  sourceRoot = "worktrunk-aarch64-apple-darwin";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp git-wt $out/bin/wt
    chmod +x $out/bin/wt

    runHook postInstall
  '';

  meta = {
    description = "Git worktree management CLI - makes worktrees as easy as branches";
    homepage = "https://github.com/max-sixty/worktrunk";
    license = lib.licenses.mit;
    mainProgram = "wt";
    platforms = [ "aarch64-darwin" ];
  };
}
