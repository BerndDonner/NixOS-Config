{ pkgs, ... }:

{
  imports = [ ../../modules/home-manager/desktop.nix ];

  home.packages = with pkgs; [
    cudatoolkit
    (unstable.blender.override {
      cudaSupport = true;
    })
  ];
  home.stateVersion = "23.11";
}
