# based on the work of Marco Feltmann: https://github.com/marcofeltmann/luametatex.nix/blob/master/context.nix

{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
} :

buildGoModule {
  pname = "BootDev";
  version = "1.11.0";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v1.11.0";
    hash = "sha256-ZQW8UBm1oeo04dvBKB2MLrwbkV1hlxNVNiispuKJLMc=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = with lib; {
    homepage = "https://github.com/bootdotdev/bootdev";
    description = "The official command line tool for Boot.dev";
    license = licenses.mit;
    maintainers = []; #TODO
  };
}

