{ config, lib, ... }:

let
  sshFiles = [
    "bernds-desktop"
    "bernds-desktop.pub"
    "bernd_tracy"
    "bernd_tracy.pub"
    "id_tabby_bootstrap"
    "id_tabby_bootstrap.pub"
    "levi_raspi.pub"
    "mct-vm-setup"
    "mct-vm-setup.pub"
  ];
in
{
  # Only links go through the Nix store; private key contents never do.
  # The age key lives in the same LUKS vault on both desktop hosts.
  home.file = builtins.listToAttrs (map (name: {
    name = ".ssh/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "/secrets/ssh/keys/${name}";
  }) sshFiles) // {
    # SOPS expects this path; never copy the private identity into the store.
    ".config/sops/age/keys.txt" = {
      source = config.lib.file.mkOutOfStoreSymlink "/secrets/sops/age/keys.txt";
    };
    # Link the entire directory, not the config file: rclone needs to
    # create temporary files here when refreshing OAuth tokens.
    ".config/rclone" = {
      source = config.lib.file.mkOutOfStoreSymlink "/secrets/rclone";
      recursive = false;
    };
  };
}
