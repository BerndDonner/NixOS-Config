{ pkgs, inputs ? {} }:
{
  promptHook        = import ./prompt-hook.nix;
  pythonDevelop     = import ./python-develop.nix;
  pythonVenvDevelop = import ./python-venv-develop.nix;
}
