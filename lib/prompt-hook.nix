{ symbol ? "❖" }:

let
  sym = symbol;
in
''
  # === Prevent double-initialization (important for PROMPT_COMMAND) ===
  if [ -n "''${PROMPT_HOOK_APPLIED:-}" ]; then
    return 0
  fi
  export PROMPT_HOOK_APPLIED=1

  # === Color definitions ===
  YELLOW="\[\033[1;33m\]"
  CYAN="\[\033[1;36m\]"
  RESET="\[\033[0m\]"

  # === Detect current project name ===
  if [ -n "$PRJ_NAME" ]; then
    PROJECT_NAME="$PRJ_NAME"
  elif [ -n "$FLAKE_NAME" ]; then
    PROJECT_NAME="$FLAKE_NAME"
  elif [ -f flake.nix ]; then
    PROJECT_NAME="$(basename "$PWD")"
  else
    PROJECT_NAME=""
  fi

  # === Initialize PS1 stack if not present ===
  if [ -z "''${PS1_STACK_INIT:-}" ]; then
    PS1_STACK=()
    PS1_STACK_INIT=1
  fi

  # === Push current prompt ===
  PS1_STACK+=("$PS1")

  # === Compose new prompt ===
  SYMBOL='${sym}'
  if [ -n "$PROJECT_NAME" ]; then
    PROMPT_PREFIX="$SYMBOL [$PROJECT_NAME]"
  else
    PROMPT_PREFIX="$SYMBOL"
  fi

  export PS1="$PROMPT_PREFIX $YELLOW\u@\h:\w\$ $RESET"

  # === Restore prompt on exit ===
  trap '
    if ((''${#PS1_STACK[@]})); then
      PS1="''${PS1_STACK[-1]}"
      unset "PS1_STACK[-1]"
    fi
  ' EXIT

  echo
  echo "${sym}  Entered Nix dev shell — project: ''${PROJECT_NAME:-unknown}"
  echo
''

