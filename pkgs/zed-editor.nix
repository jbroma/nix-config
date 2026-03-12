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
      url = "https://github.com/zed-industries/zed/releases/download/v0.227.1/Zed-aarch64.dmg";
      sha256 = "0nxvxyz7mh5jr6qvzzkgg3mcx5savzg17v4xp7kz3sljn8pzmrkx";
    };
  };
in
stdenv.mkDerivation {
  pname = "zed-editor";
  version = "0.227.1";

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
