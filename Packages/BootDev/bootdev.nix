{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
} :

buildGoModule {
  pname = "BootDev";
  version = "1.11.1";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v1.11.1";
    hash = "sha256-4XOXYcC+ghvyZ9oFg/kXn/1MdseMPIWzR4CFMVWrukw=";
  };

  vendorHash = "sha256-jhRoPXgfntDauInD+F7koCaJlX4XDj+jQSe/uEEYIMM=";

  meta = with lib; {
    homepage = "https://github.com/bootdotdev/bootdev";
    description = "The official command line tool for Boot.dev";
    license = licenses.mit;
    maintainers = []; #TODO
  };
}

