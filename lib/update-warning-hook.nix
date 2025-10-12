{ inputs
, checkInputs ? [ "nixos-config" ]
, symbol ? "⚠️"
}:

let
  sym = symbol;

  # Sanitize input names to valid Bash identifiers
  sanitize = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  # Precompute bash variables safely
  revVars = builtins.concatStringsSep "\n" (
    map (name:
      let
        safeName = sanitize name;
        rev = inputs.${name}.rev or "";
      in ''declare rev_${safeName}="${rev}"''
    ) checkInputs
  );

  # The list of original (unsanitized) input names for display/lookup
  inputList = builtins.concatStringsSep " " checkInputs;
in
''
  # === Color definitions ===
  YELLOW="\[\033[1;33m\]"
  CYAN="\[\033[1;36m\]"
  RESET="\[\033[0m\]"

  ${revVars}

  echo
  echo "''${CYAN}${sym}  Checking flake input revisions...''${RESET}"
  echo

  for inputName in ${inputList}; do
    safeName="''${inputName//-/_}"   # Bash-side sanitization too, just in case
    eval "rev=\$rev_''${safeName}"

    if [ -n "$rev" ]; then
      echo "   ''${CYAN}$inputName:''${RESET} $rev"

      # === Check for outdated lock file entry ===
      if [ -f flake.lock ]; then
        current_rev=$(jq -r ".locks.nodes.\"$inputName\".locked.rev // empty" flake.lock 2>/dev/null)
        if [ -n "$current_rev" ] && [ "$current_rev" != "$rev" ]; then
          echo "''${YELLOW}${sym}  Warning:''${RESET} input '$inputName' is outdated!"
          echo "   → Run: nix flake lock --update-input $inputName"
        fi
      fi
    else
      echo "   ''${CYAN}$inputName:''${RESET} (no revision info available)"
    fi
  done

  echo
''
