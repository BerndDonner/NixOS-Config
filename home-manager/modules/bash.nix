# home-manager/modules/bash.nix
{ config, lib, pkgs, ... }:

{
  programs.bash = {
    enable = true;

    bleSh = {
      enable = true;
      # version comes from pkgs; Home Manager wires it in your bashrc
    };

    # optional: falls du irgendwann login-shells nutzt
    profileExtra = ''
      if [[ -f ~/.bashrc ]]; then
        . ~/.bashrc
      fi
    '';
  };
}
