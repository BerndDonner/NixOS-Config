  # Workaround for sporadic resume failures/timeouts with MediaTek MT7925 (mt7925e)
  # seen as cfg80211/wiphy_resume errors (-110) after hibernation.

{ pkgs, lib, ... }:

let
  hook = pkgs.writeShellScript "wifi-sleep-hook" ''
    set -u -o pipefail

    PATH=${lib.makeBinPath [ pkgs.networkmanager pkgs.kmod ]}

    NM=nmcli
    MP=modprobe

    disconnect_wifi() {
      $NM -t -f DEVICE,TYPE dev status \
      | while IFS=: read -r dev type; do
          [ "$type" = "wifi" ] || continue
          # Correct nmcli syntax (works across nmcli versions):
          $NM dev disconnect "$dev" >/dev/null 2>&1 || true
        done
    }

    case "$1/$2" in
      pre/hibernate|pre/suspend-then-hibernate|pre/hybrid-sleep)
        disconnect_wifi
        $NM radio wifi off >/dev/null 2>&1 || true
        $NM networking off >/dev/null 2>&1 || true
        $MP -r mt7925e >/dev/null 2>&1 || true
        ;;
      post/hibernate|post/suspend-then-hibernate|post/hybrid-sleep)
        $MP mt7925e >/dev/null 2>&1 || true
        $NM networking on >/dev/null 2>&1 || true
        $NM radio wifi on >/dev/null 2>&1 || true
        ;;
    esac
  '';
in {
  environment.etc."systemd/system-sleep/wifi-reset" = {
    source = hook;
    mode = "0755";
  };
}
