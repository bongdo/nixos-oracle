{ lib, stdenv, fetchurl }:

stdenv.mkDerivation (finalAttrs: {
  pname = "x-ui";
  version = "2.8.10";

  # Upstream release tarball для aarch64. Пакет — только для этого образа.
  src = fetchurl {
    url = "https://github.com/MHSanaei/3x-ui/releases/download/v${finalAttrs.version}/x-ui-linux-arm64.tar.gz";
    hash = "sha256-2kFZfbzM7mrqrxhdxzscbefAdrNcNxu/7V6oXWTWNVE=";
  };

  sourceRoot = "x-ui";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/x-ui $out/bin
    cp -r . $out/lib/x-ui/
    ln -s $out/lib/x-ui/x-ui $out/bin/x-ui
    runHook postInstall
  '';

  meta = {
    description = "Web panel for Xray";
    homepage = "https://github.com/MHSanaei/3x-ui";
    license = lib.licenses.asl20;
    mainProgram = "x-ui";
    platforms = [ "aarch64-linux" ];
  };
})
