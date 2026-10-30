# NordVPN binary package and NixOS service

Version 6.0.1, official x86_64 Debian distribution:

https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_6.0.1_amd64.deb

This repackages the vendor binaries, not the public GPL source repository.
The .deb metadata declares `License: Proprietary`; the Nix package retains
`unfreeRedistributable`. The root flake permits this package specifically.
Existing host-wide unfree policies are unchanged.

## Package and module

`nordvpn.nix` patches the ELF interpreter/library paths, including the bundled
libraries under `lib/nordvpn`. The CLI runs natively; the daemon and its
children run in an FHS environment to provide their `/usr/lib/nordvpn` paths
and external commands. NordVPN 6.x needs `xsltproc` (libxslt) for OpenVPN
configuration. The environment also supplies nftables and systemd DNS tools.

`modules/nixos/nordvpn.nix` retains the service name `nordvpn.service` and the
existing `services.nordvpn.allowedUsers` interface. A new package option allows
explicit overrides:

```nix
services.nordvpn = {
  enable = true;
  allowedUsers = [ "bernd" ];
  # package = aDifferentNordvpnPackage;
};
```

The package must expose `bin/nordvpn`, `bin/nordvpnd` and `var/lib/nordvpn/data`.
StateDirectory manages `/var/lib/nordvpn` as root:nordvpn, mode 0750. Before
startup, missing seed data is copied atomically, including hidden files. Existing
files, settings and credentials are preserved; partial initialization can be
completed on the next start. New releases do not overwrite downloaded state.

Keep upstream's `KillMode=process` and SIGUSR1 restart signal. The reverse-path
firewall setting is retained; no inbound TCP/UDP ports are added. This module
keeps the existing always-started daemon model, without introducing vendor
socket activation or a new early-boot killswitch service. Early-boot leak
protection is not established by a successful package build.

## Verify before activation

From the repository root:

```bash
bash pkgs/nordvpn/check-state-init.sh
nix build .#nordvpn -o result-nordvpn -L
./result-nordvpn/bin/nordvpn --version
sudo nixos-rebuild build --flake .#kitty  # or .#tracy
```

The build checks CLI version and required files after ELF patching. It does
not start a VPN or validate routing, DNS, login, or killswitch behavior.
When ready to activate on that host:

```bash
sudo nixos-rebuild switch --flake .#kitty  # or .#tracy
systemctl status nordvpn.service --no-pager
journalctl -u nordvpn.service -b -n 100 --no-pager
nordvpn --version
nordvpn status
nordvpn settings
```

Then connect and check DNS/routing on the host; test both protocols you use.
For 6.x the protocol commands are e.g. `nordvpn set protocol nordlynx` and
`nordvpn set protocol openvpn_udp`. Review the vendor's 6.0 release notes for
removed aliases/commands before using old automation. Existing authentication
state is preserved; re-login only if the client requires it.

## Future updates

Read the new .deb's dependencies, files and service units before updating.
Change version/hash, then repeat package and host tests. Obtain the flat
fetchurl hash using `nix store prefetch-file --json URL`. Do not use an unpacked
NAR hash for this .deb download.
