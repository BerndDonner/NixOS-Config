# Interactive desktop Home Manager setup shared by kitty and tracy.
{ ... }:

{
  imports = [
    ./basics.nix
    ./packages.nix
    ./ssh.nix
    ./vault-links.nix
    ./git.nix
    ./git-desktop.nix
    ./tmux.nix
    ./konsole.nix
    ./vim.nix
    ./helix.nix
    ./zk.nix
  ];

  donner.helix = {
    developmentTools = true;
    steelForge = true;
  };

  programs.home-manager.enable = true;
}
