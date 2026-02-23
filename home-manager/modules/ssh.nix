{ config, pkgs, lib, inputs, ... }:

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

    matchBlocks = {
      "ai.donner-lab.org" = {
        host = "ai";
        hostname = "ai.donner-lab.org";
        user = "ubuntu";
        identityFile = "~/.ssh/id_tabby_bootstrap";
        identitiesOnly = true;
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
          UserKnownHostsFile = "~/.ssh/known_hosts_ephemeral";
          LogLevel = "ERROR";
        };
      };

      "forgejo-meisterk" = {
        host = "forgejo.meisterk.de";
        user = "git";
        identityFile = "~/.ssh/bernds-desktop";
        identitiesOnly = true;
        extraOptions = { StrictHostKeyChecking = "accept-new"; };
      };

      "lenzi" = {
        user = "levi";
        identityFile = "~/.ssh/bernd_tracy";
        identitiesOnly = true;
      };

      "*" = {
        identityFile = "~/.ssh/bernds-desktop";
        identitiesOnly = true;
      };
    };
  };
}
