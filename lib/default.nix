{ pkgs, inputs ? {} }:
{
  prompt-hook        = import ./prompt-hook.nix;
  python-develop     = import ./python-develop.nix;
  python-venv-develop = import ./python-venv-develop.nix;
}
