{ pkgs }:
pkgs.writeShellApplication {
  name = "devflake-update";
  # Nix is already available on the host when entering a devShell.
  # Do not pull a second nix CLI into every project's shell closure.
  runtimeInputs = with pkgs; [ git coreutils ];
  text = ''
    set -euo pipefail
    if [[ ! -f flake.nix || ! -f flake.lock ]]; then
      echo 'Run devflake-update from the project flake directory.' >&2
      exit 2
    fi
    nix flake update nixos-config
    echo '--- Lockfile changes ---'
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git diff -- flake.lock
    else
      echo 'No Git working tree; inspect flake.lock manually.'
    fi
    echo '--- Checking default development shell evaluation ---'
    system="$(nix eval --impure --raw --expr builtins.currentSystem)"
    nix eval --raw ".#devShells.$system.default.drvPath" >/dev/null
    echo 'The default devShell evaluates successfully (packages not built).'
  '';
}
