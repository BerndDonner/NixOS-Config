{
  description = "Python Development with Nix 24.11";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
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
        name = "impurePythonEnv";
        venvDir = "./.venv";

        packages = with pkgs; [];

        buildInputs = with pkgs; [
          python3Packages.python
          python3Packages.venvShellHook
        ];

        postVenvCreation = ''
          unset SOURCE_DATE_EPOCH
          pip install -r requirements.txt
        '';
      };
  };
}
