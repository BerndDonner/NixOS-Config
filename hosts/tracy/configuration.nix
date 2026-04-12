# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia/vaapi.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "tracy"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  services.gpm.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;


  # Enable the Plasma 5 Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  security.pam.services.sddm.kwallet.enable = true;
  

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "eu";
  };

  services.xserver.inputClassSections = [ ''
    Identifier "XP-Pen 24 Pro Tablet"
    MatchIsTablet "on"
    Driver "libinput"
    MatchUSBID "28bd:092d"
    MatchDevicePath "/dev/input/event*"
    Option "TransformationMatrix" "0.57148 0 0 0 1 0 0 0 1"
  '' ];

  # Link /home/bernd/.config/kwinoutputconfig.json to
  # /var/lib/sddm/.config/kwinoutputconfig.json. And change the ownership to
  # sddm:sddm. This is neccessary so that plamsa and sddm (display-manager)
  # use the same monitor setup. 
  # TODO: THIS DOES NOT WORK
  
  # system.activationScripts.setupPlasmaOutputConfig= lib.mkAfter ''
  #   # Ensure the target directory exists
  #   mkdir -p /var/lib/sddm/.config
    
  #   # Path to the source and target
  #   USER_HOME="/home/bernd"
  #   SOURCE="$USER_HOME/.config/kwinoutputconfig.json"
  #   TARGET="/var/lib/sddm/.config/kwinoutputconfig.json"

  #   # Check if the target exists
  #   if [ -e "$TARGET" ]; then
  #     # Backup the existing file even if it is a symlink
  #     BACKUP="$TARGET.backup.$(date +%s)"
  #     echo "Backing up existing file to $BACKUP"
  #     mv "$TARGET" "$BACKUP"
  #   fi

  #   # copy the SOURCE to the TARGET
  #   cp "$SOURCE" "$TARGET"

  #   # Set the ownership to sddm:sddm
  #   chown sddm:sddm "$TARGET"
  # '';
  

  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  services.pulseaudio.enable = false;
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.bernd = {
    isNormalUser = true;
    
    extraGroups = [
      "wheel"   # Enable ‘sudo’ for the user.
      "dialout" # Enable access to ttyACM0 for arduino programming
      "audio"   # Enable audio changes
    ];

    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDD18j4MrhelwgKsBMftVpClYd1YOzVAfyUmwo33nW/dk2pJn3qv2FHyYFj2Fn/od8lBLuKqymImCUy60Q8VjCSscnzVeNaaTY7rPUeznmzSEKTULMXBhXpu0fs4RdMP+OIm00inH3aP4M5VLqP6q0OKCWxWskR4Q1QP33kMZhEyzxfGVsxNrT8rJDEnyycVFGV0itPIeWxKFp+PV9kAFLBmiIu0ymxCoTYNItYlJRyXhrUZcyfAbBpQEkbwjZbchEuFFf5Idnan0CPQeeExZWePHT+FHHrVYsSdeijELPAl7tCzPdckrCO4Iz+g6vAn5suyJM6YngnJGjvx8iYDs2kUgdh8A6W45He4ezRa6GbvD7chH3LQ3lHJ6qyw6thoTHqUnIlKuQlAi9aplJ2b7h/QLjOLhDe6wsYSKjx7cQg/bi2WEalMw/aGVVPFvou1ZScNCAI++BOhSJy7pJWTp+yjOV9+tt1KpG2W7s6ONro5jZC+hBak28JzVI5s6KvWak= levi@lenzi" ];
    packages = with pkgs; [];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    w3m
    gpm
    git
    fd
    bc
    zip
    unzip
    usbutils
    pciutils
    imagemagick
    ghostscript
    glxinfo
    cudatoolkit
    vaapiVdpau
    nvidia-vaapi-driver
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
  
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  services.nordvpn = {
    enable = true;
    allowedUsers = [ "bernd" ];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # all this crap does not help with suspend!
  boot = {
    kernelParams = [ "nvidia_drm.fbdev=1" ];
    
    extraModprobeConfig =
      "options nvidia "
      + lib.concatStringsSep " " [
        # nvidia assume that by default your CPU does not support PAT,
        # but this is effectively never the case in 2023
        "NVreg_UsePageAttributeTable=1"
        # This is sometimes needed for ddc/ci support, see
        # https://www.ddcutil.com/nvidia/
        #
        # Current monitor does not support it, but this is useful for
        # the future
        "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
      ];
  };

  environment.variables = {
    # Required to run the correct GBM backend for nvidia GPUs on wayland
    GBM_BACKEND = "nvidia-drm";
    # Apparently, without this nouveau may attempt to be used instead
    # (despite it being blacklisted)
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Hardware cursors are currently broken on nvidia
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  hardware.nvidia = {
    # does not help with suspend!
    #forceFullCompositionPipeline = true;

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    #powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    # The nvidia-settings build is currently broken due to a missing
    # vulkan header; re-enable whenever
    # 0384602eac8bc57add3227688ec242667df3ffe3the hits stable.
    nvidiaSettings = false;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.

    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "580.76.05";
      sha256_64bit = "sha256-IZvmNrYJMbAhsujB4O/4hzY8cx+KlAyqh7zAVNBdl/0=";
      sha256_aarch64 = lib.fakeHash;
      openSha256 = "sha256-xEPJ9nskN1kISnSbfBigVaO6Mw03wyHebqQOQmUg/eQ=";
      settingsSha256 = lib.fakeHash;
      persistencedSha256 = lib.fakeHash;
    };

    vaapi = {
      enable = true;
      firefox.enable = true;
    };
  };

  # programs.nix-ld.enable = true;
  #
  # programs.nix-ld.libraries = with pkgs; [
  #   # Add any missing dynamic libraries for unpackaged programs
  #   # here, NOT in environment.systemPackages
  #   # ./electron/dist/libvulkan.so.1
  #   # ./electron/dist/libffmpeg.so
  #   # ./electron/dist/libvk_swiftshader.so
  #   # ./electron/dist/libGLESv2.so
  #   # ./electron/dist/libEGL.so
  # ];

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?

}

