{ config, pkgs, ... }:

let
  notebookDir = "${config.home.homeDirectory}/zk-notes";

  zkWrapped = pkgs.writeShellApplication {
    name = "zk";

    text = ''
      if [ "$#" -eq 0 ]; then
        exec ${pkgs.zk}/bin/zk \
          --notebook-dir "${notebookDir}" \
          edit --interactive
      else
        exec ${pkgs.zk}/bin/zk \
          --notebook-dir "${notebookDir}" \
          "$@"
      fi
    '';
  };
in
{
  home.packages = [
    zkWrapped
  ];

  programs = {
    fzf.enable = true;
    bat.enable = true;
  };
}
