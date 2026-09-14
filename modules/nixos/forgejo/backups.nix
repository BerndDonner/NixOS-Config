{ pkgs, ... }:

{
  # Native PostgreSQL backup for Forgejo. Do not rely on forgejo-db.sql from
  # `forgejo dump` for PostgreSQL restore.
  systemd.tmpfiles.rules = [
    "d /var/backup/forgejo/postgres 0750 postgres postgres -"
  ];

  systemd.services.forgejo-pg-dump = {
    description = "Native PostgreSQL dump for Forgejo";

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      SupplementaryGroups = [ "forgejo" ];
      UMask = "0077";
    };

    script = ''
      set -euo pipefail

      timestamp=$(${pkgs.coreutils}/bin/date +%s)
      target="/var/backup/forgejo/postgres/forgejo-$timestamp.dump"

      ${pkgs.postgresql}/bin/pg_dump \
        --format=custom \
        --file="$target" \
        forgejo

      ${pkgs.findutils}/bin/find \
        /var/backup/forgejo/postgres \
        -type f \
        -name 'forgejo-*.dump' \
        -mtime +28 \
        -delete
    '';
  };

  systemd.timers.forgejo-pg-dump = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "*-*-* 03:40:00";
      Persistent = true;
      Unit = "forgejo-pg-dump.service";
    };
  };

  systemd.services.forgejo-offsite-backup = {
    description = "Encrypted Forgejo backup to Backblaze B2";

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = ''
      set -euo pipefail

      ${pkgs.rclone}/bin/rclone \
        --config /home/bleau/.config/rclone/rclone.conf \
        sync \
        /var/backup/forgejo \
        b2-crypt:
    '';
  };

  systemd.timers.forgejo-offsite-backup = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "*-*-* 03:50:00";
      Persistent = true;
      Unit = "forgejo-offsite-backup.service";
    };
  };
}
