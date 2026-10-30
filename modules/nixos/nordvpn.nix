{ config, lib, pkgs, ... }:

let
  cfg = config.services.nordvpn;
  initializeState = pkgs.writeShellApplication {
    name = "nordvpn-init-state";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils ];
    text = builtins.readFile ../../pkgs/nordvpn/init-state.sh;
  };
in
with lib; {
  options.services.nordvpn = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the NordVPN daemon.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/nordvpn/nordvpn.nix { };
      description = "NordVPN package including the daemon launcher and seed data.";
    };

    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        System users that are allowed to control NordVPN.
        They will be added to the "nordvpn" group.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.checkReversePath = false;

    environment.systemPackages = [ cfg.package ];

    users.groups.nordvpn.members = cfg.allowedUsers;

    systemd.services.nordvpn = {
      description = "NordVPN daemon";

      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];

      serviceConfig = {
        User = "root";
        ExecStart = "${cfg.package}/bin/nordvpnd";

        ExecStartPre = "${initializeState}/bin/nordvpn-init-state ${cfg.package}/var/lib/nordvpn /var/lib/nordvpn";
        StateDirectory = "nordvpn";
        StateDirectoryMode = "0750";

        # Match the vendor's process lifecycle; child processes may survive a
        # daemon restart. Do not change this to control-group without testing.
        KillMode = "process";
        Restart = "on-failure";
        RestartSec = 5;
        RestartKillSignal = "SIGUSR1";

        RuntimeDirectory = "nordvpn";
        RuntimeDirectoryMode = "0750";

        Group = "nordvpn";
      };
    };
  };
}
