{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

stdenv.mkDerivation rec {
  name = "handy";
  version = "0.7.1";

  src = fetchurl {
    url = "https://github.com/cjpais/Handy/releases/download/v${version}/Handy_${version}_aarch64.dmg";
    sha256 = "10vp79m1x8d5bhsgckdk3q6gylrgzh5f010ihwjx8awi139dihsh";
  };

  nativeBuildInputs = [ _7zz ];

  sourceRoot = ".";
  installPhase = ''
    mkdir -p "$out/Applications"
    cp -r Handy/Handy.app "$out/Applications/Handy.app"
  '';

  meta = with lib; {
    homepage = "https://github.com/cjpais/Handy";
    description = "A free, open source, and extensible speech-to-text application that works completely offline";
    platforms = [ "aarch64-darwin" ];
    license = licenses.mit;
  };
}
