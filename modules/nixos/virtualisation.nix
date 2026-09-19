{ config, pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;

  # Use QEMU from the pinned unstable package set for newer display features
  # while keeping the rest of the host on the stable NixOS release.
  virtualisation.libvirtd.qemu.package = pkgs.unstable.qemu_kvm;

  programs.virt-manager.enable = true;

  # Optional, aber sinnvoll:
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virtiofsd
    OVMF
  ];

  # Für AMD:
  boot.kernelModules = [ "kvm-amd" ];

  # User darf VMs managen.
  #
  # kvm-arduino is deliberately a HOST-only group. It grants QEMU access to
  # the raw USB device node of an Arduino Uno R3 so that `-device usb-host`
  # can pass the real USB device through to a guest. The guest does not need
  # this group; inside Bunny the Arduino remains a normal /dev/ttyACM* device
  # controlled by the guest's dialout group.
  users.groups."kvm-arduino" = { };
  users.users.bernd.extraGroups = [ "libvirtd" "kvm" "kvm-arduino" ];

  # Raw USB passthrough for the official Arduino Uno R3 (2341:0043).
  #
  # Without this rule, /dev/bus/usb/<bus>/<device> is normally root:root 0664
  # on this host. QEMU, running as user bernd, can read but cannot write/claim
  # the device. Giving only kvm-arduino group members rw access keeps the rule
  # narrower than MODE="0666" and survives unplug/replug via udev.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2341", ATTR{idProduct}=="0043", GROUP="kvm-arduino", MODE="0660"
  '';
}
