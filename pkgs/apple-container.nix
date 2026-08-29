# Apple's container CLI (Linux containers in lightweight VMs on macOS 26).
# nixpkgs lags upstream; this repacks the same signed installer at a newer version. Keep it
# until nixpkgs reaches >= 1.2.0 (CVE-2026-64777, CVE-2026-64786 fixes matter for the sandbox).
# https://github.com/apple/container/releases
{ container, fetchurl }:
container.overrideAttrs (
  finalAttrs: _: {
    version = "1.3.0";
    src = fetchurl {
      url = "https://github.com/apple/container/releases/download/${finalAttrs.version}/container-${finalAttrs.version}-installer-signed.pkg";
      hash = "sha256-vRViUMuEBhNn7UsO7vUiEbaoJcbgcoqUJuV2At2wicE=";
    };
  }
)
