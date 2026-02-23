# home-manager/modules/bash.nix
{ config, lib, pkgs, ... }:

{
  programs.bash = {
    enable = true;

    # optional: falls du irgendwann login-shells nutzt
    profileExtra = ''
      if [[ -f ~/.bashrc ]]; then
        . ~/.bashrc
      fi
    '';
  };
}
