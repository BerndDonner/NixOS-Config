{ config, lib, pkgs, ... }:

let
  cfg = config.services.nordvpn;
  nordVpnPkg = pkgs.callPackage ../pkgs/nordvpn/nordvpn.nix { };
in
with lib; {
  options.services.nordvpn = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the NordVPN daemon.";
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

    environment.systemPackages = [ nordVpnPkg ];

    users.groups.nordvpn.members = cfg.allowedUsers;

    systemd.services.nordvpn = {
      description = "NordVPN daemon";

      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${nordVpnPkg}/bin/nordvpnd";

        ExecStartPre = pkgs.writeShellScript "nordvpn-start" ''
          mkdir -m 700 -p /var/lib/nordvpn
          if [ -z "$(ls -A /var/lib/nordvpn)" ]; then
            cp -r ${nordVpnPkg}/var/lib/nordvpn/* /var/lib/nordvpn
          fi
        '';

        KillMode = "process";
        Restart = "on-failure";
        RestartSec = 5;

        RuntimeDirectory = "nordvpn";
        RuntimeDirectoryMode = "0750";

        Group = "nordvpn";
      };
    };
  };
}
