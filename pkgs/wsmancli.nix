{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  autoreconfHook,
  pkg-config,
  curl,
  libxml2,
  perl,
  openssl,
  pam,
  sblim-sfcc,
}:

let
  openwsman = stdenv.mkDerivation (finalAttrs: {
    pname = "openwsman";
    version = "2.8.1";

    src = fetchFromGitHub {
      owner = "Openwsman";
      repo = "openwsman";
      tag = "v${finalAttrs.version}";
      hash = "sha256-jXsnjnYZ2UiEj3sJDhMuWlopIECKLraqgIV4evw5Tbw=";
    };

    nativeBuildInputs = [
      cmake
      pkg-config
    ];

    buildInputs = [
      curl
      libxml2
      openssl
      sblim-sfcc
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [ pam ];

    cmakeFlags = [
      "-DCMAKE_BUILD_RUBY_GEM=OFF"
      "-DBUILD_BINDINGS=OFF"
      "-DBUILD_EXAMPLES=OFF"
      "-DBUILD_JAVA=OFF"
      "-DBUILD_PERL=OFF"
      "-DBUILD_PYTHON=OFF"
      "-DBUILD_PYTHON3=OFF"
      "-DBUILD_RUBY=OFF"
      "-DBUILD_SWIG_PLUGIN=OFF"
      "-DBUILD_TESTS=OFF"
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      "-DDISABLE_SERVER=ON"
      "-DUSE_PAM=OFF"
    ];

    preConfigure = ''
      appendToVar cmakeFlags "-DPACKAGE_ARCHITECTURE=$(uname -m)"
    '';

    postInstall = lib.optionalString stdenv.hostPlatform.isDarwin ''
      substituteInPlace "$out/lib/pkgconfig/openwsman.pc" \
        --replace-fail \
          "Libs: -L$out/lib -lwsman -lwsman_client -lwsman_curl_client_transport " \
          "Libs: -L$out/lib -lwsman -lwsman_client -L${curl.out}/lib -lcurl -L${libxml2.out}/lib -lxml2 -L${openssl.out}/lib -lssl -lcrypto "
    '';
  });
in
stdenv.mkDerivation (finalAttrs: {
  pname = "wsmancli";
  version = "2.8.0";

  src = fetchFromGitHub {
    owner = "Openwsman";
    repo = "wsmancli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pTA5p5+Fuiw2lQaaSKnp/29HMy8NZNTFwP5K/+sJ9OU=";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    perl
  ];

  buildInputs = [
    openwsman
    openssl
  ];

  postPatch = ''
    touch AUTHORS NEWS README

    perl -0pi -e 's/\s*\\\n\s*-lwsman_curl_client_transport//g' \
      src/Makefile.am \
      examples/Makefile.am \
      tests/interop/Makefile.am
  '';

  meta = {
    description = "Openwsman command-line client";
    longDescription = ''
      Openwsman provides a command-line tool, wsman, to perform basic
      operations on the command-line. These operations include Get, Put,
      Invoke, Identify, Delete, Create, and Enumerate. The command-line tool
      also has several switches to allow for optional features of the
      WS-Management specification and testing.
    '';
    downloadPage = "https://github.com/Openwsman/wsmancli/releases";
    homepage = "https://openwsman.github.io";
    license = lib.licenses.bsd3;
    mainProgram = "wsman";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
