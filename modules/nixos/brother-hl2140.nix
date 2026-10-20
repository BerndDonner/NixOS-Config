# Brother HL-2140, local CUPS queue on each NixOS host.
# No printer sharing: the printer is connected either directly via USB
# or to a FRITZ!Box acting as a raw TCP print server.
{ pkgs, ... }:

let
  # USB: the printer can be plugged into tracy OR kitty as needed.
  # If CUPS reports a different URI, check: lpinfo -v | grep -i brother
  deviceUri = "usb://Brother/HL-2140%20series";

  # Alternative (after physically connecting the printer to a FRITZ!Box):
  # deviceUri = "socket://<IP-of-the-FRITZ-Box>:9100";
  # Use the address of the box with the USB cable, not necessarily the
  # mesh master. Disable the FRITZ!Box USB remote-connection feature.
in
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother_HL2140";
        description = "Brother HL-2140";
        inherit deviceUri;
        model = "drv:///brlaser.drv/br2140.ppd";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "Brother_HL2140";
  };
}
