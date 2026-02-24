# home-manager/modules/bash.nix
{ config, lib, pkgs, ... }:

{
  programs.bash = {
    enable = true;

    # Wichtig: ble.sh muss VOR starship init laufen
    initExtra = ''
      # ble.sh (required for Starship right prompt in bash)
      source ${pkgs.blesh}/share/blesh/ble.sh --attach=none
      [[ $- == *i* ]] && ble-attach

      # Starship (after ble.sh)
      eval "$(${pkgs.starship}/bin/starship init bash)"
    '';

    # optional: falls du irgendwann login-shells nutzt
    profileExtra = ''
      if [[ -f ~/.bashrc ]]; then
        . ~/.bashrc
      fi
    '';
  };
}
