{ lib, stdenv, fetchFromGitHub, buildGoModule }:

buildGoModule rec {
  pname = "bootdev-cli";
  version = "1.20.4";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    hash = "sha256-ayjHhnnP6YWKMItsAw+nnScf1/eEHN2f7cOIkskE3mM=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  # Optional: smaller binary
  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "CLI used to complete coding challenges and lessons on Boot.dev";
    homepage = "https://github.com/bootdotdev/bootdev";
    license = licenses.mit;
    mainProgram = "bootdev";
  };
}

