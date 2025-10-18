
# python-base-shell.nix
{ pkgs
, symbol ? "🐍"
, pythonVersion ? pkgs.python3
, extraPackages ? [ ]
, message ? "🐍 Python development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ ]         # optional inputs to verify
}:

let
  promptHook = import ./prompt-hook.nix { inherit symbol; };

  updateWarningHook =
    if inputs != null && checkInputs != [ ] then
      import ./update-warning-hook.nix {
        inherit inputs;
        inherit checkInputs;
        symbol = "⚠️";
      }
    else
      ""; # no-op if not provided
in
pkgs.mkShell {
  name = "python-env";

  shell = pkgs.bashInteractive;

  packages = with pkgs; [
    pythonVersion
    pythonVersion.pkgs.pip
    pythonVersion.pkgs.setuptools
    pythonVersion.pkgs.wheel
    pythonVersion.pkgs.ipython
    pythonVersion.pkgs.black
    pythonVersion.pkgs.isort
    jq
  ] ++ extraPackages;

  shellHook = ''
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export PATH=${pkgs.bashInteractive}/bin:$PATH

    PROMPT_FILE="$(mktemp)"
    cat >"$PROMPT_FILE" <<'EOF'
${promptHook}
EOF
    export PROMPT_COMMAND="source $PROMPT_FILE"

    ${updateWarningHook}
    echo "${message}"
  '';
}
