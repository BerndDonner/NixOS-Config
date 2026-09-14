{ pkgs, ... }:

let
  webDomain = "git.the-darkroom.org";
  sshDomain = "ssh.the-darkroom.org";
  forgejoPackage = pkgs.forgejo-lts;

  identityHook = pkgs.writeShellScript "forgejo-check-commit-identity" ''
    set -euo pipefail

    readonly allowed_name='bleau'
    readonly allowed_email='bleau@noreply.git.the-darkroom.org'

    failed=0
    declare -A checked=()

    while read -r _oldrev newrev _refname; do
      # Ref deletion
      [[ "$newrev" =~ ^0+$ ]] && continue

      # Ignore refs that do not ultimately point to a commit.
      ${pkgs.git}/bin/git cat-file -e "$newrev^{commit}" 2>/dev/null || continue

      # Check commits newly introduced to this Forgejo repository.
      while read -r commit; do
        [[ -n "''${checked[$commit]:-}" ]] && continue
        checked["$commit"]=1

        mapfile -t ident < <(
          ${pkgs.git}/bin/git show -s \
            --format='%an%n%ae%n%cn%n%ce' \
            "$commit"
        )

        author_name="''${ident[0]-}"
        author_email="''${ident[1]-}"
        committer_name="''${ident[2]-}"
        committer_email="''${ident[3]-}"

        if [[ "$author_name" != "$allowed_name" ||
              "$author_email" != "$allowed_email" ||
              "$committer_name" != "$allowed_name" ||
              "$committer_email" != "$allowed_email" ]]; then

          short="$(${pkgs.git}/bin/git rev-parse --short "$commit")"

          echo >&2
          echo "ERROR: commit $short has an invalid Git identity:" >&2
          echo "  Author:    $author_name <$author_email>" >&2
          echo "  Committer: $committer_name <$committer_email>" >&2
          echo >&2
          echo "Required identity:" >&2
          echo "  bleau <bleau@noreply.git.the-darkroom.org>" >&2
          echo >&2

          failed=1
        fi
      done < <(
        ${pkgs.git}/bin/git rev-list "$newrev" --not --all
      )
    done

    exit "$failed"
  '';
in
{
  environment.systemPackages = [
    forgejoPackage
  ];

  # Native PostgreSQL backup for Forgejo.
  # Do not rely on forgejo-db.sql from `forgejo dump` for PostgreSQL restore.
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

  systemd.services.forgejo-identity-hooks = {
    description = "Install Forgejo commit identity hooks";

    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail

      repoRoot="/var/lib/forgejo/data/forgejo-repositories/bleau"

      # The account may not have repositories yet.
      [[ -d "$repoRoot" ]] || exit 0

      shopt -s nullglob

      for repo in "$repoRoot"/*.git; do
        hookDir="$repo/hooks/pre-receive.d"

        ${pkgs.coreutils}/bin/install \
          -d \
          -o forgejo \
          -g forgejo \
          -m 0750 \
          "$hookDir"

        ${pkgs.coreutils}/bin/ln \
          -sfn \
          ${identityHook} \
          "$hookDir/10-identity"
      done
    '';
  };

  systemd.paths.forgejo-identity-hooks = {
    description = "Watch for new Forgejo repositories";

    wantedBy = [ "multi-user.target" ];

    pathConfig.PathChanged =
      "/var/lib/forgejo/data/forgejo-repositories/bleau";
  };

  
  # ---------------------------------------------------------------------------
  # Forgejo
  # ---------------------------------------------------------------------------
  services.forgejo = {
    enable = true;

    # Stay on Forgejo's LTS line for infrastructure that should be boring and
    # predictable. NixOS 26.05 currently uses forgejo-lts by default as well,
    # but keeping this explicit documents the decision.
    package = forgejoPackage;

    # Local PostgreSQL via Unix socket. With createDatabase = true the NixOS
    # Forgejo module creates the database/user and wires /run/postgresql in for
    # us, so no database password is required.
    database = {
      type = "postgres";
      createDatabase = true;
    };

    # Blender files and other selected binary assets can be kept out of normal
    # Git object storage with Git LFS. The LFS data stays local for now; moving
    # it to separate storage later does not require changing repository data.

    lfs.enable = true;

    dump = {
      enable = true;
      interval = "03:30";
      type = "tar.zst";
      backupDir = "/var/backup/forgejo";
      age = "4w";
    };

    settings = {
      DEFAULT = {
        APP_NAME = "The Darkroom";
      };

      server = {
        DOMAIN = webDomain;
        ROOT_URL = "https://${webDomain}/";

        # Forgejo itself is not exposed to the network. Caddy is the only HTTP
        # entry point and reverse-proxies to this loopback listener.
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;

        # Use the system OpenSSH server on port 22 for Git. Since Forgejo runs
        # as the dedicated `forgejo` system user, this is also the SSH user in
        # the clone URL.
        START_SSH_SERVER = false;
        SSH_DOMAIN = sshDomain;
        SSH_PORT = 22;
        SSH_USER = "forgejo";
      };

      session.COOKIE_SECURE = true;

      # This is a private forge: no public account creation and no anonymous
      # browsing. The initial administrator is created once via the Forgejo CLI
      # after deployment.
      service = {
        DISABLE_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        REQUIRE_SIGNIN_VIEW = true;
        DEFAULT_USER_VISIBILITY = "private";
        DEFAULT_ORG_VISIBILITY = "private";
      };

      # Even if a repository is created through a different UI/API path, keep
      # it private. This is deliberate for the NSFW/private instance.
      repository = {
        FORCE_PRIVATE = true;
        DEFAULT_PRIVATE = "private";
        DEFAULT_BRANCH = "master";
      };

      # Keep Actions available from day one, but do not run a runner on this
      # small VPS. Runners can be registered on another machine later.
      actions = {
        ENABLED = true;
        ARTIFACT_RETENTION_DAYS = 30;
      };

      # No OpenID logins/signups are needed on this single-user private forge.
      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };

      security = {
        DISABLE_GIT_HOOKS = true;
      };
    };
  };

  # ---------------------------------------------------------------------------
  # HTTPS reverse proxy
  # ---------------------------------------------------------------------------
  # git.the-darkroom.org is DNS-only at Cloudflare, so Caddy talks directly to
  # the ACME CA and terminates TLS on cloud. WebSockets are handled by Caddy's
  # reverse_proxy automatically.
  services.caddy = {
    enable = true;

    virtualHosts.${webDomain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy 127.0.0.1:3000
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
