{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation rec {
  name = "android-studio";
  version = "2025.3.3.6";
  dmgName = "android-studio-panda3-mac_arm.dmg";

  src = fetchurl {
    url = "https://redirector.gvt1.com/edgedl/android/studio/install/${version}/${dmgName}";
    sha256 = "e28009b47e248f9fcf32bfd33335cb616390d92133af1e8ed5f6ef61cff007c3";
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
