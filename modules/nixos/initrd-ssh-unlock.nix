# Remote LUKS unlock via a temporary SSH server in systemd stage 1.
# NetworkManager and the stage-2 SSH server are not involved.
{ config, lib, ... }:

let
  # Each machine keeps its own private host key outside the repository.
  hostKey = "/persist/initrd-ssh/${config.networking.hostName}/ssh_host_ed25519_key";

  # The same client keys are accepted for bernd in the normal system, but
  # initrd permits only the password agent (no root shell or forwarding).
  unlockKeys = map (
    key: ''restrict,pty,command="/bin/systemd-tty-ask-password-agent --watch" ${key}''
  ) config.users.users.bernd.openssh.authorizedKeys.keys;
in
{
  # 26.05 uses systemd in the initrd; keep that explicit here.
  boot.initrd.systemd.enable = true;

  # Common drivers for tracy's onboard Ethernet and kitty's USB-C adapters.
  # Check `lspci -k` / `lsusb -t` if a different adapter is used.
  boot.initrd.availableKernelModules = [
    "r8169"
    "igc"
    "e1000e"
    "r8152"
    "ax88179_178a"
    "cdc_ether"
    "cdc_ncm"
  ];

  # Independent Ethernet DHCP only during stage 1. It does NOT take over
  # either host's network configuration after switch-root.
  boot.initrd.systemd.network = {
    enable = true;
    wait-online.enable = false;
    networks."10-initrd-ethernet" = {
      matchConfig.Type = "ether";
      networkConfig.DHCP = "ipv4";
      linkConfig.RequiredForOnline = "no";
    };
  };

  # The agent is not present in the minimal initrd by default.
  boot.initrd.systemd.extraBin.systemd-tty-ask-password-agent =
    "${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent";

  boot.initrd.network.ssh = {
    enable = true;
    port = 2222;
    hostKeys = [ hostKey ];
    authorizedKeys = unlockKeys;
    extraConfig = ''
      PermitRootLogin forced-commands-only
      AllowUsers root
      DisableForwarding yes
      KbdInteractiveAuthentication no
    '';
  };

  # Refuse an accidentally empty key list instead of exposing an SSH server
  # whose intended authentication workflow cannot be used.
  assertions = [
    {
      assertion = unlockKeys != [ ];
      message = "initrd-ssh-unlock: bernd needs at least one authorized SSH key";
    }
  ];
}
