{ symbol ? "❖" }:

''
  # === Save current prompt ===
  export OLD_PS1="$PS1"

  # === Color definitions ===
  YELLOW="\[\033[1;33m\]"   # bright yellow (visible on dark bg)
  RESET="\[\033[0m\]"       # reset colors
  # Symbols themselves can be colored too, if desired
  GREEN="\[\033[1;32m\]"
  CYAN="\[\033[1;36m\]"
  MAGENTA="\[\033[1;35m\]"
  BLUE="\[\033[1;34m\]"

  # === Set symbol (provided by caller) ===
  SYMBOL="${symbol}"

  # === Compose new prompt ===
  export PS1="${SYMBOL} ${YELLOW}\u@\h:\w\$ ${RESET}"

  # === Restore old prompt on exit ===
  trap 'PS1="$OLD_PS1"' EXIT

  echo
  echo "${SYMBOL}  Entered Nix dev shell — prompt color changed to yellow"
  echo
''

