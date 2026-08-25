# agent-device - built from the published npm tarball (not in nixpkgs).
# The tarball ships no lockfile and its devDependencies use pnpm workspace
# specifiers, so package-lock.json here was generated from the tarball with
# devDependencies and peerDependencies removed:
#   curl -sL <tarball> | tar xz && cd package
#   jq 'del(.devDependencies, .peerDependencies)' package.json > p && mv p package.json
#   npm install --package-lock-only --ignore-scripts
# Update: bump version, refresh package-lock.json the same way, then
#   nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url <tarball>)"   -> src.hash
#   nix run nixpkgs#prefetch-npm-deps -- package-lock.json                          -> npmDeps.hash
{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
  fetchurl,
  jq,
}:
buildNpmPackage (finalAttrs: {
  pname = "agent-device";
  version = "0.20.10";

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-device/-/agent-device-${finalAttrs.version}.tgz";
    hash = "sha256-K7LHDgNnvEBRS/l+Z6XRA4RKlB+MqQen8/b0eBl9gsE=";
  };

  npmDeps = fetchNpmDeps {
    src = ./.;
    hash = "sha256-TxEVX8d0Y3rxX/24r0MVd822CQnzmJ73VDeONaYx6I0=";
  };

  nativeBuildInputs = [ jq ];

  # prepack would run the monorepo's pnpm build during `npm pack`; the tarball is already built.
  postPatch = ''
    jq 'del(.devDependencies, .peerDependencies, .scripts.prepack)' package.json > package.json.new
    mv package.json.new package.json
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = {
    description = "Mobile app automation and verification for AI coding agents";
    homepage = "https://github.com/callstack/agent-device";
    license = lib.licenses.mit;
    mainProgram = "agent-device";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
})
