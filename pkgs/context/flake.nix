{
  description = "ConTeXt (LMTX / LuaMetaTeX) package flake for Bernd’s NixOS setup";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      # ------------------------------------------------------------------------
      # 🧱 Packages
      # ------------------------------------------------------------------------
      packages.${system} = {
        luametatex = pkgs.callPackage ./luametatex.nix {};
        default = self.packages.${system}.luametatex;
      };

      # ------------------------------------------------------------------------
      # 🧩 Metadata
      # ------------------------------------------------------------------------
      meta = {
        description = "ConTeXt LuaMetaTeX engine packaged via Nix flake";
        homepage = "https://wiki.contextgarden.net";
        maintainers = [ "Bernd Donner" ];
        license = pkgs.lib.licenses.gpl3Plus;
      };
    };
}

