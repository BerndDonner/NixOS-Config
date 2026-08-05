# /etc/nixos/configuration.nix  (kitty)

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./vault.nix
    ./hibernate-hooks.nix
  ];

  # Bootloader (eigene EFI-Partition auf der NixOS-SSD)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems.exfat = true;

  # Hibernate (swap partition)
  boot.resumeDevice = "/dev/disk/by-uuid/c4072834-5654-415d-a8af-95e8e160dc5b";

  # Ensure the kernel actually attempts resume (do not override other params)
  boot.kernelParams = lib.mkAfter [
    "resume=/dev/disk/by-uuid/c4072834-5654-415d-a8af-95e8e160dc5b"
    "nvme_core.default_ps_max_latency_us=0"
  ];

  # Force a reliable hibernation path: "platform" (firmware-assisted) resume can fail on some AMD/UEFI laptops
  # with errors like "inconsistent memory map / image mismatch". Using HibernateMode=shutdown makes hibernate
  # use the kernel-managed shutdown/resume flow, which is typically much more stable.
  systemd.sleep.extraConfig = ''
    HibernateMode=shutdown
    HibernateDelaySec=2min
  '';

  # Force the kernel default hibernation mode early at boot so user space (KDE/logind) can't end up using "platform".
  systemd.tmpfiles.rules = [
    "w /sys/power/disk - - - - shutdown"
  ];

  # boot.blacklistedKernelModules = [
  #   "mt7925e"
  #   "mt7925_common"
  #   "mt76"
  #   "mt76_connac_lib"
  # ];

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "kitty";
  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  services.gpm.enable = true;

  # GUI: Plasma 6
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  security.pam.services.sddm.kwallet.enable = true;

  services.xserver.xkb = {
    layout = "eu";
  };

  # Printing
  services.printing.enable = true;

  # Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User
  users.users.bernd = {
    isNormalUser = true;

    extraGroups = [
      "wheel"
      "dialout"
      "audio"
      "networkmanager"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDD18j4MrhelwgKsBMftVpClYd1YOzVAfyUmwo33nW/dk2pJn3qv2FHyYFj2Fn/od8lBLuKqymImCUy60Q8VjCSscnzVeNaaTY7rPUeznmzSEKTULMXBhXpu0fs4RdMP+OIm00inH3aP4M5VLqP6q0OKCWxWskR4Q1QP33kMZhEyzxfGVsxNrT8rJDEnyycVFGV0itPIeWxKFp+PV9kAFLBmiIu0ymxCoTYNItYlJRyXhrUZcyfAbBpQEkbwjZbchEuFFf5Idnan0CPQeeExZWePHT+FHHrVYsSdeijELPAl7tCzPdckrCO4Iz+g6vAn5suyJM6YngnJGjvx8iYDs2kUgdh8A6W45He4ezRa6GbvD7chH3LQ3lHJ6qyw6thoTHqUnIlKuQlAi9aplJ2b7h/QLjOLhDe6wsYSKjx7cQg/bi2WEalMw/aGVVPFvou1ZScNCAI++BOhSJy7pJWTp+yjOV9+tt1KpG2W7s6ONro5jZC+hBak28JzVI5s6KvWak= levi@lenzi"
    ];

    packages = with pkgs; [ ];
  };

  # Nix + Unfree (firmware etc.)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Packages (wie tracy, aber NVIDIA-Kram komplett entfernt)
  environment.systemPackages = with pkgs; [
    cryptsetup
    e2fsprogs
    exfatprogs
    wget
    w3m
    git
    fd
    bc
    zip
    blesh
    starship
    unzip
    usbutils
    pciutils
    imagemagick
    ghostscript
    mesa-demos
    vulkan-tools
    wayland-utils
  ];

  environment.sessionVariables = {
    XDG_SESSION_TYPE = "wayland";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    OZONE_PLATFORM_HINT = "wayland";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    carlito
  ];

  fonts.enableDefaultPackages = true;
  fonts.fontDir.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  # NordVPN
  services.nordvpn = {
    enable = true;
    allowedUsers = [ "bernd" ];
  };

  # Wichtig: auf dem neuen System so lassen (Installer-Wert nutzen)
  system.stateVersion = "25.11";
}

