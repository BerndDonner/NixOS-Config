# Shared KDE Plasma / Wayland desktop configuration for kitty and tracy.
{ pkgs, ... }:

{
  hardware.graphics.enable = true;
  services.xserver = {
    enable = true;
    xkb.layout = "eu";
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  security.pam.services.sddm.kwallet.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

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
}
