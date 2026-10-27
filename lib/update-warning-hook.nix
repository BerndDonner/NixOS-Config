# Evaluates the consumer's lock file, then performs a bounded, cached remote
# check when entering a shell. Never changes the lock file, even on failure.
{ pkgs, flakeLockPath, checkInputs ? [ "nixos-config" ] }:
let
  lib = pkgs.lib;
  lock = if builtins.pathExists flakeLockPath then
    builtins.fromJSON (builtins.readFile flakeLockPath)
    else throw "update-warning-hook: no flake.lock at ${toString flakeLockPath}";
  # Resolve aliases from root.inputs (flake input names are not guaranteed
  # to equal internal node ids in flake.lock).
  nodeFor = name:
    let target = lock.nodes.root.inputs.${name} or name;
        nodeId = if builtins.isList target then builtins.elemAt target 0 else target;
    in lock.nodes.${nodeId} or { };
  mkCheck = name:
    let
      node = nodeFor name;
      locked = node.locked or { };
      original = node.original or { };
      owner = locked.owner or original.owner or "";
      repo = locked.repo or original.repo or "";
      remote = "https://github.com/${owner}/${repo}.git";
      # Explicit refs are respected; otherwise query the default HEAD.
      ref = if original ? ref then "refs/heads/${original.ref}" else "HEAD";
      rev = locked.rev or "";
    in if (locked.type or "") != "github" || rev == "" then ""
       else if owner == "NixOS" && repo == "nixpkgs" then ""
       else ''
         check_one ${lib.escapeShellArg name} ${lib.escapeShellArg remote} \
           ${lib.escapeShellArg ref} ${lib.escapeShellArg rev}
       '';
  commands = builtins.concatStringsSep "\n" (map mkCheck checkInputs);
  script = pkgs.writeShellScript "devshell-update-warning" ''
    # This program only reports differences. Network failures never prevent
    # entering the development shell.
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/devflake-updates"
    cache_ttl=21600 # 6 hours
    check_one() {
      local name="$1" remote="$2" ref="$3" pinned="$4"
      local key cache_file last now remote_rev
      if [[ "''${DEVFLAKE_UPDATE_CHECK:-}" == "off" ]]; then return 0; fi
      key=$(printf '%s\n' "$name" "$remote" "$ref" "$pinned" | ${pkgs.coreutils}/bin/sha256sum)
      key="''${key%% *}"
      cache_file="$cache_dir/$key"
      if [[ "''${DEVFLAKE_UPDATE_CHECK:-}" != "force" && -f "$cache_file" ]]; then
        last=$(${pkgs.coreutils}/bin/stat -c %Y "$cache_file" 2>/dev/null || printf 0)
        now=$(${pkgs.coreutils}/bin/date +%s)
        if (( now >= last && now - last < cache_ttl )); then
          remote_rev=$(${pkgs.coreutils}/bin/cat "$cache_file" 2>/dev/null || true)
        fi
      fi
      if [[ -z "''${remote_rev:-}" ]]; then
        remote_rev=$(${pkgs.coreutils}/bin/timeout 5s \
          ${pkgs.git}/bin/git -c credential.interactive=never \
          ls-remote "$remote" "$ref" 2>/dev/null \
          | ${pkgs.gawk}/bin/awk 'NR==1 {print $1}' || true)
        if [[ -z "$remote_rev" ]]; then
          printf '  ⚠ %s: update check skipped (offline / remote unavailable)\n' "$name"
          return 0
        fi
        ${pkgs.coreutils}/bin/mkdir -p "$cache_dir" 2>/dev/null || true
        printf '%s\n' "$remote_rev" > "$cache_file" 2>/dev/null || true
      fi
      if [[ "$remote_rev" != "$pinned" ]]; then
        printf '  ⚠ %s: upstream revision differs from pinned revision\n' "$name"
        printf '    pinned: %s\n    remote: %s\n' "$pinned" "$remote_rev"
        printf '    To update: devflake-update (or nix flake update %s)\n' "$name"
      fi
    }
    ${commands}
    exit 0
  '';
in
"${pkgs.bash}/bin/bash ${script}"
