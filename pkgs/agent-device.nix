# agent-device - the published npm tarball (not in nixpkgs). Since 0.21 it bundles
# its dependencies, so it only needs node to run.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "agent-device";
  version = "0.21.14";

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-device/-/agent-device-${finalAttrs.version}.tgz";
    hash = "sha256-KVouAwTwiBkr8d0gsViPiRJp58uOEZ2PllPOphQp5N0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/agent-device
    cp -R . $out/lib/agent-device
    makeWrapper ${lib.getExe nodejs} $out/bin/agent-device \
      --add-flags $out/lib/agent-device/bin/agent-device.mjs
    runHook postInstall
  '';

  meta = {
    description = "Mobile app automation and verification for AI coding agents";
    homepage = "https://github.com/callstack/agent-device";
    license = lib.licenses.mit;
    mainProgram = "agent-device";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
})
