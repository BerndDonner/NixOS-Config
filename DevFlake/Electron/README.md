# Electron development on NixOS

The system-wide `lib/electron-develop.nix` is a reusable base for
project-specific JavaScript, Electron, and VS Code extension shells.

It provides:

- Node.js 22
- Python, `pkg-config`, GCC, and GNU Make for `node-gyp`
- `libudev.h` and `libudev.pc` through `systemd.dev`
- libusb headers
- an optional Electron package
- optional `vscode-fhs`
- a writable npm global prefix below `~/.cache/npm/global`

## Arduino Maker Workshop

Copy `project-flake.nix` to the repository as `flake.nix`, then run:

```bash
nix develop
rm -rf node_modules
npm ci
npm run compile
```

Launch VS Code from inside the shell:

```bash
code .
```

Here `code` resolves to `vscode-fhs`.

## Standalone Electron projects

The reusable function enables Electron by default:

```nix
default = electronDev {
  inherit pkgs;
  nodejsPackage = pkgs.nodejs_22;
  electronPackage = pkgs.electron;
  codePackage = pkgs.vscode-fhs;
};
```

For a VS Code extension, `includeElectron = false` avoids adding an
unrelated second Electron runtime.
