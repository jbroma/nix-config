{
  stdenv,
  lib,
  fetchurl,
  unzip,
}:
let
  version = "0.9.0";
in
stdenv.mkDerivation {
  pname = "maestro-studio";
  inherit version;

  src = fetchurl {
    url = "https://github.com/mobile-dev-inc/maestro-studio/releases/download/v${version}/Maestro-Studio-mac-universal.zip";
    sha256 = "91e1932f64986552eaffc76dd503c6169eb5c42733280695bf00722492d1cdee";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "$PWD" "$out/Applications/"

    actual=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$out/Applications/Maestro Studio.app/Contents/Info.plist")
    if [ "$actual" != "${version}" ]; then
      echo "ERROR: Version mismatch! Expected ${version}, got $actual" >&2
      echo "Update the version in maestro-studio.nix to: $actual" >&2
      exit 1
    fi

    runHook postInstall
  '';

  meta = {
    description = "Desktop app for Maestro mobile and web test automation";
    homepage = "https://github.com/mobile-dev-inc/maestro-studio";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
  };
}
