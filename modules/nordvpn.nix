{ config, lib, pkgs, ... }:

let
  # Reuse the package from pkgs/nordvpn.nix
  nordVpnPkg = pkgs.callPackage ../pkgs/nordvpn/nordvpn.nix { };
in
with lib; {
  options.myypo.services.custom.nordvpn.enable = mkOption {
    type = types.bool;
    default = false;
    description = ''
      Whether to enable the NordVPN daemon. Note that you will have
      to set `networking.firewall.checkReversePath = false;`, allow
      UDP 1194 and TCP 443 in your firewall and add your user to
      the "nordvpn" group (`users.users.<username>.extraGroups`).
    '';
  };

  config = mkIf config.myypo.services.custom.nordvpn.enable {
    # NordVPN sometimes breaks with reverse path filtering enabled
    networking.firewall.checkReversePath = false;

    # Make CLI available system-wide
    environment.systemPackages = [ nordVpnPkg ];

    # Basic group setup for NordVPN users
    users.groups.nordvpn.members = [ "bernd" ];

    systemd.services.nordvpn = {
      description = "NordVPN daemon";

      # Start after network is up
      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${nordVpnPkg}/bin/nordvpnd";

        # Initialize /var/lib/nordvpn on first start only
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

