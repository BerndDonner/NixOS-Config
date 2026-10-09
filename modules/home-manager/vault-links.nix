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
  # The age key link already lives in each host's home.nix.
  home.file = builtins.listToAttrs (map (name: {
    name = ".ssh/${name}";
    value.source = config.lib.file.mkOutOfStoreSymlink "/secrets/ssh/keys/${name}";
  }) sshFiles) // {
    ".config/rclone/rclone.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/secrets/rclone/rclone.conf";
  };

  # Adopt only the manual symlinks created during the vault migration.
  # Any regular file or unexpected link is left for Home Manager's normal
  # collision check (we deliberately do not use `force = true`).
  home.activation.adoptManualVaultLinks =
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for name in ${lib.escapeShellArgs sshFiles}; do
        existing="$HOME/.ssh/$name"
        if [ -L "$existing" ] &&
           [ "$(readlink "$existing")" = "/secrets/ssh/keys/$name" ]; then
          rm -- "$existing"
        fi
      done

      existing="$HOME/.config/rclone/rclone.conf"
      if [ -L "$existing" ] &&
         [ "$(readlink "$existing")" = "/secrets/rclone/rclone.conf" ]; then
        rm -- "$existing"
      fi
    '';
}
