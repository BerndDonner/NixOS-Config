{ ... }:

{
  imports = [
    ./forgejo/service.nix
    ./forgejo/proxy.nix
    ./forgejo/backups.nix
    ./forgejo/identity-hooks.nix
  ];
}
