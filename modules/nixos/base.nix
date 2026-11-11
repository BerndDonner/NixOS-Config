# Settings shared by the two interactive NixOS hosts (kitty and tracy).
# The headless cloud host intentionally does not import this module.
{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };
  services.gpm.enable = true;

  users.users.bernd = {
    isNormalUser = true;
    extraGroups = [ "wheel" "dialout" "audio" ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDD18j4MrhelwgKsBMftVpClYd1YOzVAfyUmwo33nW/dk2pJn3qv2FHyYFj2Fn/od8lBLuKqymImCUy60Q8VjCSscnzVeNaaTY7rPUeznmzSEKTULMXBhXpu0fs4RdMP+OIm00inH3aP4M5VLqP6q0OKCWxWskR4Q1QP33kMZhEyzxfGVsxNrT8rJDEnyycVFGV0itPIeWxKFp+PV9kAFLBmiIu0ymxCoTYNItYlJRyXhrUZcyfAbBpQEkbwjZbchEuFFf5Idnan0CPQeeExZWePHT+FHHrVYsSdeijELPAl7tCzPdckrCO4Iz+g6vAn5suyJM6YngnJGjvx8iYDs2kUgdh8A6W45He4ezRa6GbvD7chH3LQ3lHJ6qyw6thoTHqUnIlKuQlAi9aplJ2b7h/QLjOLhDe6wsYSKjx7cQg/bi2WEalMw/aGVVPFvou1ZScNCAI++BOhSJy7pJWTp+yjOV9+tt1KpG2W7s6ONro5jZC+hBak28JzVI5s6KvWak= levi@lenzi"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCuzORt+Ta4fGIHAQajtUesaYnq0YhsAFAhsWTrKs3RmuB1q4/rmZh3p9nZQGJjxB7bC7TxSWA0tl7BTAt916hhwhzGtiBSHecC4VyfMKg/322LPAtmZycaF9WW3F+lSfbLiLWgmtvBMy6xX2Avm7zmS7cdH11U0TkxshVgijqjLFBIeC9M5dzdo9qouScsn/EdcSvj1ZgZ5Ah5+RP8Dcd6onQieA017FJSfxaj7Oxb/Wc1EkfHbY6K1GN0Jh+hq6wU2bzmvq9AHqas88l24Suzmb4Psc/lVANB+TrH2PaM7CG1TX4pPAC1mrf7xUUCEOWWRkft/hBDx9ja5H9FSFkE6TNNOd7aXVqsjGtGu/oFVf7nX1ey6oTR72DHbGEwtDO5ky6eME092dpjQnd9HmrSkSeIJhzGt9pmQHisQcJpNYKXHazN3LOfd3lTl5m5XnsHUbC06RfqtifuIe2ifgdCtuwSR1oEPCJpfjVTzEcJTZ2IcinjfAdYL2Xnv5judt0= Bernds-Desktop"
    ];
    packages = with pkgs; [ ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

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

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  services.nordvpn = {
    enable = true;
    allowedUsers = [ "bernd" ];
  };
}
