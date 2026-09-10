{ config, pkgs, lib, inputs, ... }:

{
  qt.enable = true;
  fonts.fontconfig.enable = true;

  programs.java = {
    enable = true;
    package = pkgs.jre_minimal;
  };
}
