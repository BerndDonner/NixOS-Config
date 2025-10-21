{ inputs
, checkInputs ? [ ]
, symbol ? "⚠️"
}:

let
  # Read the lock file (relative to where this module lives)
  flakeLock =
    builtins.fromJSON (builtins.readFile ../flake.lock);

  sanitize = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  getInfo = name:
    let
      node = flakeLock.nodes.${name}.locked or {};
      typ  = node.type or "";
      url  =
        if typ == "github" then
          "github:${node.owner or ""}/${node.repo or ""}"
        else
          node.url or "";
      rev  = node.rev or "";
    in { inherit url rev; };

  revVars = builtins.concatStringsSep "\n" (
    map (name:
      let info = getInfo name;
          safe = sanitize name;
      in ''
        declare rev_${safe}="${info.rev}"
        declare url_${safe}="${info.url}"
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

  printf "%b\n" "''${CYAN}${symbol}  Checking flake input revisions...''${RESET}"
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
      branch=$(curl -s "https://api.github.com/repos/$repo" | jq -r .default_branch)

      # Prepare optional token header
      if [ -n "$GITHUB_TOKEN" ]; then
        AUTH_HEADER="-H Authorization: Bearer $GITHUB_TOKEN"
      else
        AUTH_HEADER=""
      fi

      # Skip huge nixpkgs repo for speed
      if [[ "$repo" == "NixOS/nixpkgs" ]]; then
        printf "%b\n" "        (skipping nixpkgs remote check)"
        continue
      fi

      # --- Fast GitHub API query ---
      latest_rev=$(curl -s $AUTH_HEADER \
        "https://api.github.com/repos/$repo/commits/$branch" |
        jq -r .sha 2>/dev/null)

      # --- Fallback to git ls-remote (works for any Git host) ---
      if [ -z "$latest_rev" ] || [ "$latest_rev" = "null" ]; then
        remote_url="https://github.com/$repo.git"
        latest_rev=$(timeout 6s git ls-remote "$remote_url" HEAD 2>/dev/null | awk '{print $1}')
      fi

      # --- Compare and warn ---
      if [ -n "$latest_rev" ] && [ "$latest_rev" != "$rev" ]; then
        printf "%b\n" "''${YELLOW}${symbol}  Notice:''${RESET} newer upstream revision detected!"
        printf "%b\n" "        → Latest upstream: $latest_rev"
        printf "%b\n" "        → Run: nix flake lock --update-input $inputName"
      fi
    else
      # For non-GitHub inputs, do a simple ls-remote check if possible
      latest_rev=$(timeout 6s git ls-remote "$url" HEAD 2>/dev/null | awk '{print $1}')
      if [ -n "$latest_rev" ] && [ "$latest_rev" != "$rev" ]; then
        printf "%b\n" "''${YELLOW}${symbol}  Notice:''${RESET} $inputName has newer revision $latest_rev"
      fi
    fi
  done

  printf "\n"
''
