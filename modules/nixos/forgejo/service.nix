{ pkgs, ... }:

let
  webDomain = "git.the-darkroom.org";
  sshDomain = "ssh.the-darkroom.org";
  forgejoPackage = pkgs.forgejo-lts;
in
{
  environment.systemPackages = [
    forgejoPackage
  ];

  services.forgejo = {
    enable = true;

    # Stay on Forgejo's LTS line for infrastructure that should be boring and
    # predictable.
    package = forgejoPackage;

    # Local PostgreSQL via Unix socket. With createDatabase = true the NixOS
    # Forgejo module creates the database/user and wires /run/postgresql in for
    # us, so no database password is required.
    database = {
      type = "postgres";
      createDatabase = true;
    };

    # Blender files and other selected binary assets can be kept out of normal
    # Git object storage with Git LFS.
    lfs.enable = true;

    # Forgejo's own application-data dump. PostgreSQL is backed up separately
    # with pg_dump in backups.nix.
    dump = {
      enable = true;
      interval = "03:30";
      type = "tar.zst";
      backupDir = "/var/backup/forgejo";
      age = "4w";
    };

    settings = {
      DEFAULT.APP_NAME = "The Darkroom";

      server = {
        DOMAIN = webDomain;
        ROOT_URL = "https://${webDomain}/";

        # Forgejo itself is not exposed directly. Caddy is the HTTP entry
        # point and reverse-proxies to this loopback listener.
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;

        # Use the system OpenSSH server on port 22 for Git.
        START_SSH_SERVER = false;
        SSH_DOMAIN = sshDomain;
        SSH_PORT = 22;
        SSH_USER = "forgejo";
      };

      session.COOKIE_SECURE = true;

      # Private forge: no public account creation and no anonymous browsing.
      service = {
        DISABLE_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        REQUIRE_SIGNIN_VIEW = true;
        DEFAULT_USER_VISIBILITY = "private";
        DEFAULT_ORG_VISIBILITY = "private";
      };

      repository = {
        FORCE_PRIVATE = true;
        DEFAULT_PRIVATE = "private";
        DEFAULT_BRANCH = "master";
      };

      actions = {
        ENABLED = true;
        ARTIFACT_RETENTION_DAYS = 30;
      };

      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };

      # Keep user-configurable repository hooks disabled. The identity policy
      # is installed declaratively by identity-hooks.nix instead.
      security.DISABLE_GIT_HOOKS = true;
    };
  };
}
