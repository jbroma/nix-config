{
  stdenv,
  lib,
  fetchurl,
  unzip,
}:

stdenv.mkDerivation rec {
  name = "minisim";
  version = "0.10.0";

  src = fetchurl {
    url = "https://github.com/okwasniewski/MiniSim/releases/download/v${version}/MiniSim.app.zip";
    sha256 = "b6af5775f0afb1b3c12a438fc35c1f4207a87341fbd39e256e6d3fbfa5aca64d";
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
