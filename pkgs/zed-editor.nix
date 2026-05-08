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
      url = "https://github.com/zed-industries/zed/releases/download/v1.1.7/Zed-aarch64.dmg";
      sha256 = "0g9bryc26h2v3yqa9gcq7vsxcr5cmz8fx7q9gn3h9rx34agdyf06";
    };
  };
in
stdenv.mkDerivation {
  pname = "zed-editor";
  version = "1.1.7";

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
