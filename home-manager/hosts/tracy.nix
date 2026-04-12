{ pkgs, ... }:

{
  home.stateVersion = "23.11";

  home.packages = with pkgs; [
    cudatoolkit
    (blender.override {
      cudaSupport = true;
    })
  ];
}
