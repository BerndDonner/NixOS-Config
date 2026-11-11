# Desktop with NVIDIA GPU and XP-Pen tablet (tracy).
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/initrd-ssh-unlock.nix
    ./hardware-configuration.nix
    ./nvidia/vaapi.nix
    ./vault.nix
  ];

  networking.hostName = "tracy";

  environment.systemPackages = with pkgs; [
    cudatoolkit
    libva-vdpau-driver
    nvidia-vaapi-driver
  ];

  services.xserver.inputClassSections = [ ''
    Identifier "XP-Pen 24 Pro Tablet"
    MatchIsTablet "on"
    Driver "libinput"
    MatchUSBID "28bd:092d"
    MatchDevicePath "/dev/input/event*"
    Option "TransformationMatrix" "0.57148 0 0 0 1 0 0 0 1"
  '' ];

  # Enable OpenGL
  hardware.graphics.enable = true;

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

    package = config.boot.kernelPackages.nvidiaPackages.stable;

    vaapi = {
      enable = true;
      firefox.enable = true;
    };
  };


  # Preserve tracy's original host-specific compatibility baseline.
  system.stateVersion = "23.11";
}
