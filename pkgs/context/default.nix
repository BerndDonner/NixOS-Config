# default.nix
{ pkgs }:
{
  luametatex = pkgs.callPackage ./luametatex.nix { }
}
