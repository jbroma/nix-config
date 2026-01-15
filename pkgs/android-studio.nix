{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation rec {
  name = "android-studio";
  version = "2025.2.2.8";

  src = fetchurl {
    url = "https://redirector.gvt1.com/edgedl/android/studio/install/${version}/android-studio-${version}-mac_arm.dmg";
    sha256 = "2e6c6eb3e911b42d08a3340bae6ad8759ddc894b4c3199272252f2343535496f";
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
