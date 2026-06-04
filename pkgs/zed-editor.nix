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
      url = "https://github.com/zed-industries/zed/releases/download/v1.5.3/Zed-aarch64.dmg";
      sha256 = "12zfmzm7k9lccdyw5a2rph7d9213pdm926jxdwrk406frgxgxx3i";
    };
  };
in
stdenv.mkDerivation {
  pname = "zed-editor";
  version = "1.5.3";

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
