{
  stdenv,
  lib,
  fetchurl,
  unzip,
}:

stdenv.mkDerivation rec {
  name = "minisim";
  version = "0.9.1";

  src = fetchurl {
    url = "https://github.com/okwasniewski/MiniSim/releases/download/v${version}/MiniSim.app.zip";
    sha256 = "9936c1ea78da3141a162051ffb00c0d116b58908275eafea5b2be7897fcc840a";
  };

  buildInputs = [ unzip ];

  sourceRoot = ".";
  installPhase = ''
    mkdir -p "$out/Applications"
    cp -r "MiniSim.app" "$out/Applications/MiniSim.app"
  '';

  meta = with lib; {
    homepage = "https://www.minisim.app/";
    description = "App for launching iOS and Android simulators";
    platforms = platforms.darwin;
  };
}
