{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation rec {
  name = "android-studio";
  version = "2026.1.1.10";
  dmgName = "android-studio-quail1-patch2-mac_arm.dmg";

  src = fetchurl {
    url = "https://redirector.gvt1.com/edgedl/android/studio/install/${version}/${dmgName}";
    sha256 = "69a13f8b7430f91919ff8b958c941d69953c13095e29fafa51e77d32417521a2";
  };
  buildInputs = [ undmg ];

  sourceRoot = ".";
  installPhase = ''
    mkdir -p "$out/Applications"
    cp -r "Android Studio.app" "$out/Applications/Android Studio.app"
  '';

  meta = with lib; {
    homepage = "https://developer.android.com/studio";
    description = "Android Studio provides the fastest tools for building apps on every type of Android device.";
    platforms = platforms.darwin;
  };
}
