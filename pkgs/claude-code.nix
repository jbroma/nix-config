# Claude Code - native binary install (not npm)
# Update with: mise run cc:update
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  procps,
}:
let
  version = "2.1.17";

  # Platform-specific sources from manifest.json
  sources = {
    "aarch64-darwin" = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/darwin-arm64/claude";
      hash = "sha256-HYGafA7RrWJ19CzytnBBq4Ca+xzTU3xu1uYYuI5aBTE=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/claude
    chmod +x $out/bin/claude

    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --prefix PATH : ${lib.makeBinPath [ procps ]}
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = [
      "aarch64-darwin"
    ];
  };
}
