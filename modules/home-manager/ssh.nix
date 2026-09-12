{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # IP fallback: connect to ephemeral instances by IP with the disposable key
    extraConfig = ''
      Match host *, exec "echo %h | grep -Eq '^([0-9]{1,3}\\.){3}[0-9]{1,3}$'"
        User ubuntu
        IdentityFile ~/.ssh/id_tabby_bootstrap
        IdentitiesOnly yes
        StrictHostKeyChecking accept-new
        UserKnownHostsFile ~/.ssh/known_hosts_ephemeral
        LogLevel ERROR
    '';

    settings = {
      "ai" = {
        HostName = "ai.donner-lab.org";
        User = "ubuntu";
        IdentityFile = "~/.ssh/id_tabby_bootstrap";
        IdentitiesOnly = true;
        StrictHostKeyChecking = "accept-new";
        UserKnownHostsFile = "~/.ssh/known_hosts_ephemeral";
        LogLevel = "ERROR";
      };

      "forgejo.meisterk.de" = {
        User = "git";
        IdentityFile = "~/.ssh/bernds-desktop";
        IdentitiesOnly = true;
        StrictHostKeyChecking = "accept-new";
      };

      "ssh.the-darkroom.org" = {
        User = "forgejo";
        IdentityFile = "~/.ssh/bernds-desktop";
        IdentitiesOnly = true;

        ControlMaster = "auto";
        ControlPath = "~/.ssh/control-%C";
        ControlPersist = "5m";
      };

      "lenzi" = {
        User = "levi";
        IdentityFile = "~/.ssh/bernd_tracy";
        IdentitiesOnly = true;
      };

      "*" = {
        IdentityFile = "~/.ssh/bernds-desktop";
        IdentitiesOnly = true;
      };
    };
  };
}
