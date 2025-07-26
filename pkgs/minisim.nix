{
  stdenv,
  lib,
  fetchurl,
  unzip,
}:

stdenv.mkDerivation rec {
  name = "minisim";
  version = "0.9.0";

  src = fetchurl {
    url = "https://github.com/okwasniewski/MiniSim/releases/download/v${version}/MiniSim.app.zip";
    sha256 = "467b92b291e9f28f755f245d21018045242d11dd703db414c1d078852abf971f";
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
