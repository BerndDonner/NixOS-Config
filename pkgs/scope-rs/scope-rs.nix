{
  lib,
  rustPlatform,
  pkg-config,
  systemd,
  scopeRsSrc,
}:

rustPlatform.buildRustPackage rec {
  pname = "scope-monitor";
  version = "0.6.0";

  # The source is a pinned non-flake input from the top-level flake.
  # Keeping it as a flake input means flake.lock carries the source pin;
  # no separate fetchFromGitHub hash is needed here.
  src = scopeRsSrc;

  # Scope ships a Cargo.lock. Importing it directly avoids maintaining a
  # separate cargoHash and makes dependency changes visible in flake.lock /
  # the upstream lock file.
  cargoLock = {
    lockFile = scopeRsSrc + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  # libudev is required by serialport/probe-rs on Linux.
  buildInputs = [
    systemd
  ];

  # Scope has end-to-end TUI tests using PTYs. For this local package the
  # upstream release is used as-is; keep rebuilds lean and deterministic.
  doCheck = false;

  meta = with lib; {
    description = "Multiplatform serial monitor with Lua plugin support";
    homepage = "https://github.com/matheuswhite/scope-rs";
    license = [ licenses.mit licenses.asl20 ];
    mainProgram = "scope";
    platforms = platforms.linux;
  };
}
