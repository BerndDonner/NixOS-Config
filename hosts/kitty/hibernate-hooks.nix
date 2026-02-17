  # Workaround for sporadic resume failures/timeouts with MediaTek MT7925 (mt7925e)
  # seen as cfg80211/wiphy_resume errors (-110) after hibernation.

{ config, pkgs, lib, ... }:

let
  wifiHibernateHook = pkgs.writeShellScript "wifi-hibernate-hook" ''
    set -euxo pipefail

    case "''${1:-}" in
      pre)
        ${pkgs.networkmanager}/bin/nmcli networking off || true
        ${pkgs.kmod}/bin/modprobe -r mt7925e || true
        ${pkgs.kmod}/bin/modprobe -r mt76_connac_lib mt76 || true
        ;;
      post)
        ${pkgs.kmod}/bin/modprobe mt7925e || true
        ${pkgs.networkmanager}/bin/nmcli networking on || true
        ;;
      *)
        echo "usage: $0 pre|post" >&2
        exit 2
        ;;
    esac
  '';
in
{
  systemd.services.wifi-reset-around-hibernate = {
    description = "Unload/reload mt7925e around hibernation to avoid resume timeouts";
    before = [ "systemd-hibernate.service" ];
    wantedBy = [ "systemd-hibernate.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${wifiHibernateHook} pre";
      ExecStop  = "${wifiHibernateHook} post";
    };
  };
}

