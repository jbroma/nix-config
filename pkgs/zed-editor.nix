{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

let
  inherit (stdenv.hostPlatform) system;
  sources = {
    aarch64-darwin = {
      url = "https://github.com/zed-industries/zed/releases/download/v0.233.10/Zed-aarch64.dmg";
      sha256 = "0immm19vxwhy9chxfkdkfwqbflkaq2y6262sbywrqz6iwkmsizcv";
    };
  };
in
stdenv.mkDerivation {
  pname = "zed-editor";
  version = "0.233.10";

  src = fetchurl sources.${system};

  nativeBuildInputs = [ _7zz ];
  sourceRoot = ".";

  installPhase = ''
    mkdir -p "$out/Applications" "$out/bin"
    cp -r "Zed.app" "$out/Applications/Zed.app"
    ln -s "$out/Applications/Zed.app/Contents/MacOS/cli" "$out/bin/zed"
  '';

  meta = with lib; {
    homepage = "https://zed.dev";
    description = "High-performance, multiplayer code editor";
    license = licenses.gpl3Only;
    platforms = [ "aarch64-darwin" ];
  };
}
