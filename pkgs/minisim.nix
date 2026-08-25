{
  stdenv,
  fetchurl,
  unzip,
}:
let
  version = "0.10.0";
in
stdenv.mkDerivation {
  pname = "minisim";
  inherit version;

  src = fetchurl {
    url = "https://github.com/okwasniewski/MiniSim/releases/download/v${version}/MiniSim.app.zip";
    hash = "sha256-tq9XdfCvsbPBKkOPw1wfQgeoc0H7054lbm0/v6Wspk0=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R MiniSim.app "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "App for launching iOS and Android simulators";
    homepage = "https://www.minisim.app/";
    platforms = [ "aarch64-darwin" ];
  };
}
