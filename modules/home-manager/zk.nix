{ ... }:

{
  programs = {
    zk.enable = true;

    # Required for `zk edit --interactive`
    fzf.enable = true;

    # Pretty preview of Markdown notes inside fzf
    bat.enable = true;

    bash.initExtra = ''
      zk() {
        if [ "$#" -eq 0 ]; then
          command zk edit --interactive
        else
          command zk "$@"
        fi
      }
    '';
  };
}
