{ inputs
, checkInputs ? [ "nixos-config" ]
, symbol ? "⚠️"
}:

let
  sym = symbol;
  sanitize = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  revVars = builtins.concatStringsSep "\n" (
    map (name:
      let
        safe = sanitize name;
        rev = inputs.${name}.rev or "";
        url = inputs.${name}.url or "";
      in ''
        declare rev_${safe}="${rev}"
        declare url_${safe}="${url}"
      ''
    ) checkInputs
  );

  list = builtins.concatStringsSep " " checkInputs;
in
''
  # === Color definitions ===
  YELLOW="\033[1;33m"
  CYAN="\033[1;36m"
  RESET="\033[0m"

  ${revVars}

  printf "%b\n" "''${CYAN}${sym}  Checking flake input revisions...''${RESET}"
  printf "\n"

  for inputName in ${list}; do
    safe="''${inputName//-/_}"
    eval "rev=\$rev_''${safe}"
    eval "url=\$url_''${safe}"

    if [ -z "$rev" ]; then
      printf "%b\n" "    ''${CYAN}$inputName:''${RESET} (no revision info available)"
      continue
    fi

    printf "%b\n" "    ''${CYAN}$inputName:''${RESET} $rev"

    # === Remote revision check ===
    if [[ "$url" == github:* ]]; then
      repo=$(echo "$url" | sed -E 's|github:([^/]+/[^/]+).*|\1|')
      branch="main"

      # Prepare optional token header
      AUTH_HEADER=""
      if [ -n "$GITHUB_TOKEN" ]; then
        AUTH_HEADER="-H \"Authorization: Bearer $GITHUB_TOKEN\""
      fi

      # Skip huge nixpkgs repo for speed
      if [[ "$repo" == "NixOS/nixpkgs" ]]; then
        printf "%b\n" "        (skipping nixpkgs remote check)"
        continue
      fi

      # --- Fast GitHub API query ---
      latest_rev=$(eval curl -s $AUTH_HEADER \
        "https://api.github.com/repos/$repo/commits/$branch" |
        jq -r .sha 2>/dev/null)

      # --- Fallback to nix if API fails ---
      if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
        latest_rev=$(timeout 6s nix flake metadata "$url" \
          --json --no-update-lock-file --accept-flake-config --quiet 2>/dev/null |
          jq -r '.locked.rev // .resolved.rev // empty')
      fi

      # --- Compare and warn ---
      if [ -n "$latest_rev" ] && [ "$latest_rev" != "$rev" ]; then
        printf "%b\n" "''${YELLOW}${sym}  Notice:''${RESET} newer upstream revision detected!"
        printf "%b\n" "        → Latest upstream: $latest_rev"
        printf "%b\n" "        → Run: nix flake lock --update-input $inputName"
      fi
    fi
  done

  printf "\n"
''
