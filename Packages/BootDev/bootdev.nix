# based on the work of Marco Feltmann: https://github.com/marcofeltmann/luametatex.nix/blob/master/context.nix

{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
} :

buildGoModule {
  pname = "figurine";
  version = "v1.11.0";

  src = fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${version}";
    hash = "";
  };

  vendorSha256 = "";

  meta = with lib; {
    homepage = "https://github.com/bootdotdev/bootdev";
    description = "The official command line tool for Boot.dev";
    license = licenses.mit;
    maintainers = []; #TODO
  };
}

