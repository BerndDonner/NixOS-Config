# My NixOS Configuration

Welcome to my NixOS configuration repository.  
It contains my system configuration as well as custom Nix packages and development environments.

---

## 🧩 LuaMetaTeX (ConTeXt LMTX) Package

One of the highlights of this repository is the **LuaMetaTeX** package located in the  
[`pkgs/context`](./pkgs/context) subdirectory.

This Nix package is based on the excellent work of [Marco Feltmann](https://github.com/marcofeltmann/luametatex.nix/blob/master/context.nix)  
and has been adapted for a modern flake-based setup.

### ✨ Key Features

- **Up-to-date sources** – uses the current repository from [contextgarden/context](https://github.com/contextgarden/context)  
- **Essential fonts** – downloads the `texmf.zip` archive from [Pragma ADE](http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip)  
- **Ready-to-use commands** – builds `luametatex`, `mtxrun`, and `context` binaries that mirror upstream behavior  

### 💡 Why LuaMetaTeX?

The ConTeXt typesetting system, primarily developed by Hans Hagen, offers a leaner and more structured codebase than LaTeX.  
In practice, ConTeXt provides a cleaner macro language, integrated fonts and layouts, and very high-quality PDF output.

### 🛠 Building the package

From the repository root:

```bash
nix build .#context
```

The resulting binaries will appear in `./result/bin/`.

To show more detailed build information:

```bash
nix build .#context --show-trace
```

A legacy non-flake build still works for compatibility:

```bash
nix-build -A luametatex pkgs/context
```

---

## 🏠 Personal NixOS Configuration

This repository also serves as a backup for my personal NixOS and Home-Manager configuration.  
It may not be optimal in every respect, but it reflects my current setup and customization efforts.

### 🔁 Rebuilding the System

To apply changes to your system:

```bash
sudo nixos-rebuild switch
```

If fonts are missing or new ones were installed:

```bash
fc-cache -r
```

---

Feel free to explore, adapt, and reuse any part of this configuration for your own NixOS setup.
---

## Arduino Uno USB passthrough with QEMU/KVM on `kitty`

`kitty` is the KVM-enabled host in this repository. For the MCT Bunny VMs,
the Arduino Uno R3 is passed through as the **real USB device** with QEMU, for
example:

```bash
-device usb-host,vendorid=0x2341,productid=0x0043
```

QEMU opens the raw host USB node under `/dev/bus/usb/...`. By default that
node is typically `root:root` with mode `0664`, so an unprivileged QEMU process
can read it but cannot write to or claim the device. A one-off `setfacl` works,
but the ACL disappears when the Arduino is unplugged because udev creates a
new device node on the next plug-in.

The KVM module therefore creates the host-only group `kvm-arduino`, adds
`bernd` to it, and installs a narrowly scoped udev rule for the official Uno R3
USB ID `2341:0043`:

```nix
users.groups."kvm-arduino" = { };
users.users.bernd.extraGroups = [ "libvirtd" "kvm" "kvm-arduino" ];

services.udev.extraRules = ''
  SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
    ATTR{idVendor}=="2341", ATTR{idProduct}=="0043", \
    GROUP="kvm-arduino", MODE="0660"
'';
```

This is intentionally **host-side only**. The Bunny guest does not contain or
need the `kvm-arduino` group. After passthrough, the guest sees the real Arduino
as usual (normally `/dev/ttyACM0`), and guest access remains controlled by the
normal `dialout` group. Converting the Bunny image to VMware therefore does not
carry any `kvm-arduino` configuration into the student VM.

After changing this configuration on `kitty`:

```bash
sudo nixos-rebuild switch --flake .#kitty
```

Log out and back in once so the current login session picks up the new group,
then unplug/replug the Uno. Verify on the host:

```bash
id -nG | tr ' ' '\n' | grep '^kvm-arduino$'

DEV=$(
  lsusb -d 2341:0043 |
  awk '{gsub(":", "", $4); printf "/dev/bus/usb/%s/%s\n", $2, $4}'
)

ls -l "$DEV"
getfacl "$DEV"
```

The raw USB node should be owned by group `kvm-arduino` and be writable by the
group. This rule is intentionally limited to `2341:0043`; Arduino clones or
other boards with different USB vendor/product IDs need their own explicit rule.
