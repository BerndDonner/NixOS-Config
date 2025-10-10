{ pkgs
, symbol ? "🐍"
, pythonVersion ? pkgs.python3
, requirementsFile ? ./requirements.txt  # optional path to requirements.txt
, message ? "🐍 Python venv environment ready (use pip to install packages)"
}:

let
  promptHook = import ./prompt-hook.nix { inherit symbol; };
in
pkgs.mkShell {
  name = "python-venv-env";

  # include the Python interpreter and the venv helper
  packages = [
    pythonVersion
    pythonVersion.pkgs.venvShellHook
  ];

  # this variable tells venvShellHook where to place the environment
  venvDir = "./.venv";

  shellHook = ''
    ${promptHook}

    echo "${message}"
    echo

    # Create venv if it doesn't exist yet
    if [ ! -d "$venvDir" ]; then
      echo "🆕 Creating virtual environment in $venvDir"
      python -m venv "$venvDir"
    fi

    # If a requirements file exists, remind to install packages
    if [ -f "${requirementsFile}" ]; then
      echo "💡 Run: pip install -r ${requirementsFile}"
    fi

    echo "💡 Use 'pip install <package>' to add more libraries."
    echo "🐍 Python: $(python --version)"
  '';
}

