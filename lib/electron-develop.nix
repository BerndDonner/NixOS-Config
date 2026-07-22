{ pkgs
, symbol ? "⚛"
, message ? "Electron development environment ready"
, nodejsPackage ? pkgs.nodejs_22
, electronPackage ? pkgs.electron
, codePackage ? pkgs.vscode-fhs
, includeElectron ? true
, includeCode ? true
, extraPackages ? [ ]
, extraNativeBuildInputs ? [ ]
, extraBuildInputs ? [ ]
, extraShellHook ? ""
}:

let
  lib = pkgs.lib;

  nativeBuildInputs = with pkgs; [
    nodejsPackage
    python3
    pkg-config
    gcc
    gnumake
  ] ++ extraNativeBuildInputs;

  buildInputs = [
    (pkgs.systemd.dev or pkgs.systemd)
    (pkgs.libusb1.dev or pkgs.libusb1)
  ] ++ extraBuildInputs;

  runtimePackages =
    lib.optionals includeElectron [ electronPackage ]
    ++ lib.optionals includeCode [ codePackage ]
    ++ extraPackages;

  promptHook =
    if builtins.pathExists ../prompt-hook.nix
    then import ../prompt-hook.nix { inherit symbol; }
    else "";
in
pkgs.mkShell {
  name = "electron-development";

  packages = runtimePackages;
  inherit nativeBuildInputs buildInputs;

  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;
  NPM_CONFIG_PREFIX = "$HOME/.cache/npm/global";

  # Current node-addon-api headers use C++17 features such as
  # std::string_view and if constexpr.
  CXXFLAGS = "-std=c++17";

  shellHook = ''
    mkdir -p "$NPM_CONFIG_PREFIX/bin"
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

    ${promptHook}

    echo "${message}"
    echo "Node: $(node --version)"
    echo "npm:  $(npm --version)"
    ${lib.optionalString includeCode ''echo "VS Code: $(command -v code)"''}

    ${extraShellHook}
  '';
}
