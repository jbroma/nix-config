{
  lib,
  python3Packages,
  libarchive,
  perl,
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

  nativeBuildInputs = [
    perl
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

    perl -0pi -e 's/return ipaddress\.IPv6Address\(\n\s+ip\.ip\[0\]\n\s+\)  # first of \(ip, flowinfo, scope_id\) tuple/return ipaddress.IPv6Address(f"{ip.ip[0]}%{interface_name}")/' \
      opendrop/util.py

    perl -0pi -e 's/(\n    def remove_service\(self, zeroconf, service_type, name\):)/\n    def update_service(self, zeroconf, service_type, name):\n        self.add_service(zeroconf, service_type, name)\n\1/' \
      opendrop/client.py
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
