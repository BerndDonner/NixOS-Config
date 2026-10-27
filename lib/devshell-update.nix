# Common update check for development shells consuming NixOS-Config.
# Pinned flake input remains unchanged; check is informational and non-blocking.
{ pkgs, inputs ? null, flakeLockPath ? null, checkInputs ? [ "nixos-config" ] }:
if checkInputs == [ ] then ""
else if inputs == null then
  throw "DevShell update check: pass inputs = { inherit nixos-config; };"
else if flakeLockPath == null then
  throw "DevShell update check: pass flakeLockPath = ./flake.lock;"
else
  import ./update-warning-hook.nix {
    inherit pkgs flakeLockPath checkInputs;
  }
