{
  description = "JavaScript Development with Nix 24.05";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: {
    devShells = {
      x86_64-linux.default  = self.buildDevShell "x86_64-linux";
      aarch64-linux.default = self.buildDevShell "aarch64-linux";
      x86_64-darwin.default = self.buildDevShell "x86_64-darwin";
    };
  } // {
    buildDevShell = system: let
      pkgs = import nixpkgs { inherit system; };
    in
      pkgs.mkShell {
        name = "impureJavascriptEnv";

        packages = with pkgs; [
          electron_33
          nodejs_22
          node2nix
          stdenv.cc.cc.lib
        ];
        buildInputs = with pkgs; [];

        # Fixes libstdc++ and libgl.so issues
        LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/";
      };
  };
}
