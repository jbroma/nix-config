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
      url = "https://github.com/zed-industries/zed/releases/download/v1.5.5/Zed-aarch64.dmg";
      sha256 = "0w30kj8p5vm26klgvm2q86qlf83gdz7y6pay1jiiflshccr20pvm";
    };
  };
in
stdenv.mkDerivation {
  pname = "zed-editor";
  version = "1.5.5";

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
