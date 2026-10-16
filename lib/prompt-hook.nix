{ symbol ? "❖" }:

''
  # Show a welcome message when entering a dev shell.
  #
  # Do not modify PS1, PROMPT_COMMAND or shell traps here. On NixOS, ble.sh and
  # Starship manage the interactive prompt (including the Nix shell indicator).
  # Each `nix develop` starts its own shell, so no exported initialization
  # marker or prompt-restoration stack is needed for nested dev shells.
  # A subshell keeps the temporary project name out of the caller's environment.
  (
    if [ -n "''${PRJ_NAME:-}" ]; then
      project_name=$PRJ_NAME
    elif [ -n "''${FLAKE_NAME:-}" ]; then
      project_name=$FLAKE_NAME
    elif [ -f flake.nix ]; then
      project_name=''${PWD##*/}
    else
      project_name=unknown
    fi

    printf '\n%s  Entered Nix dev shell — project: %s\n\n' \
      '${symbol}' "$project_name"
  )
''
