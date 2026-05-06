{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation rec {
  name = "android-studio";
  version = "2025.3.4.7";
  dmgName = "android-studio-panda4-patch1-mac_arm.dmg";

  src = fetchurl {
    url = "https://redirector.gvt1.com/edgedl/android/studio/install/${version}/${dmgName}";
    sha256 = "e06e2609eb51d0ce84c027ec7d7a9778b2e980febadf50195c2aaf1b45098e7e";
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
