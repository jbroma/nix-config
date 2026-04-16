{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation rec {
  name = "android-studio";
  version = "2025.3.3.7";
  dmgName = "android-studio-panda3-patch1-mac_arm.dmg";

  src = fetchurl {
    url = "https://redirector.gvt1.com/edgedl/android/studio/install/${version}/${dmgName}";
    sha256 = "7de5f12c57405d5101ca27ca184e6ef5fea67b9ad76f0e78ff87194dd79aedbc";
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
