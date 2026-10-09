{ config, lib, pkgs, ... }:

{
  # Never run the directory setup on the unencrypted root filesystem.
  # Requiring secrets.mount also works with x-systemd.automount: it forces
  # the actual ext4 filesystem to be mounted before the service starts.
  systemd.services.vault-directories = {
    description = "Create directories inside the LUKS secrets vault";
    wantedBy = [ "multi-user.target" ];
    requires = [ "secrets.mount" ];
    after = [ "secrets.mount" ];
    path = [ pkgs.coreutils pkgs.util-linux ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      if ! findmnt --mountpoint /secrets --types ext4 >/dev/null; then
        echo "Refusing to initialize /secrets: ext4 vault is not mounted" >&2
        exit 1
      fi

      install -d -o bernd -g users -m 0700 /secrets

      for dir in \
        git kwallet rclone sops sops/age ssh ssh/keys \
        tokens tokens/tabby-bootstrap; do
        install -d -o bernd -g users -m 0700 "/secrets/$dir"
      done

      # System-wide NetworkManager keyfiles must remain root-owned.
      install -d -o root -g root -m 0700 /secrets/nm
    '';
  };

  # On kitty, the first boot must initialize /secrets/nm before
  # NetworkManager tries to load its system connection profiles.
  systemd.services.NetworkManager = lib.mkIf config.networking.networkmanager.enable {
    requires = [ "vault-directories.service" ];
    after = [ "vault-directories.service" ];
  };
}
