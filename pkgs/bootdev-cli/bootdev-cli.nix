{ lib, buildGoModule, fetchFromGitHub, makeWrapper, go, runtimeShell, coreutils }:

buildGoModule rec {
  pname = "bootdev-cli";
  version = "1.32.6";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "442fbee0e53eb0da7beea200cf6b92d6ef2f2b8c";
    hash = "sha256-40MI8CHvDmxVHYqnnCV2cdN4yL54feWjXrKgbEvjFQM=";
  };
  vendorHash = "sha256-LCvJDsg4MANhQ0V/ymP1heCN5rFNgeOYCYILsPdXYag=";
  subPackages = [ "." ];
  ldflags = [ "-s" "-w" ];
  nativeBuildInputs = [ makeWrapper ];
  # buildGoModule normally forbids Go in the closure; this CLI needs it at runtime.
  allowGoReference = true;

  # The version is embedded by upstream from version.txt, not by ldflags.
  # Test fixtures create scripts themselves, so patchShebangs cannot fix them.
  postPatch = ''
    export HOME="$TMPDIR/bootdev-home"
    mkdir -p "$HOME"
    test "$(cat version.txt)" = "v${version}"
    substituteInPlace version/version_test.go \
      --replace-fail '#!/bin/sh' '#!${runtimeShell}' \
      --replace-fail '/bin/sleep' '${coreutils}/bin/sleep'
  '';

  # Exercise all upstream packages, including the update-check regression tests.
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  # Boot.dev calls `go list` for its version check, even for non-Go lessons.
  # Keep a user's selected toolchain first; provide a fallback when absent.
  postFixup = ''
    wrapProgram "$out/bin/bootdev" --suffix PATH : ${lib.makeBinPath [ go ]}
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/bootdev-install-check"
    mkdir -p "$HOME"
    "$out/bin/bootdev" --version | grep -Fx 'bootdev version v${version}'
    "$out/bin/bootdev" --help > /dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "CLI used to complete coding challenges and lessons on Boot.dev";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = licenses.mit;
    mainProgram = "bootdev";
  };
}
