{
  lib,
  python3Packages,
  libarchive,
}:

python3Packages.buildPythonApplication rec {
  pname = "opendrop";
  version = "0.13.0";
  pyproject = true;

  src = python3Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-FE1oGpL6C9iBhI8Zj71Pm9qkObJvSeU2gaBZwK1bTQc=";
  };

  build-system = [
    python3Packages.setuptools
  ];

  dependencies = with python3Packages; [
    fleep
    ifaddr
    libarchive-c
    pillow
    requests
    requests-toolbelt
    zeroconf
  ];

  postPatch = ''
    substituteInPlace opendrop/config.py \
      --replace-fail "from pkg_resources import resource_filename" "from importlib.resources import files" \
      --replace-fail 'resource_filename("opendrop", "certs/apple_root_ca.pem")' 'str(files("opendrop").joinpath("certs/apple_root_ca.pem"))'
  '';

  makeWrapperArgs = [
    "--set"
    "DYLD_LIBRARY_PATH"
    "${libarchive.lib}/lib"
  ];

  pythonImportsCheck = [ "opendrop" ];

  meta = {
    description = "Open Apple AirDrop implementation";
    homepage = "https://github.com/seemoo-lab/opendrop";
    license = lib.licenses.gpl3Plus;
    mainProgram = "opendrop";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
