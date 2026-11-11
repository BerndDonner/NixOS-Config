# Remote LUKS unlock (kitty and tracy)

Both hosts import `modules/nixos/initrd-ssh-unlock.nix`. Their existing local
LUKS unlock, `/secrets`, NetworkManager (kitty), and normal SSH on port 22
stay unchanged. The initrd runs a separate, temporary OpenSSH service on port
2222 with Ethernet DHCP via systemd-networkd. No Wi-Fi, VPN or NetworkManager
profile is available in stage 1. The network is usable only if the Ethernet
adapter and its driver are present in the initrd.

## One-time setup (run **on each host** before rebuilding)

Generate a *different* dedicated initrd host key on kitty and on tracy:

```sh
host=$(hostname -s)
sudo install -d -m 0700 "/persist/initrd-ssh/$host"
sudo ssh-keygen -q -t ed25519 -N '' \
  -f "/persist/initrd-ssh/$host/ssh_host_ed25519_key"
sudo chmod 0600 "/persist/initrd-ssh/$host/ssh_host_ed25519_key"
sudo ssh-keygen -lf "/persist/initrd-ssh/$host/ssh_host_ed25519_key.pub"
```

Record and independently verify the fingerprint before accepting the SSH host
key on the client. Do **not** commit the private key, reuse the ordinary
`sshd` host key, or put the initrd key inside the encrypted `/secrets` vault.

NixOS systemd-boot appends this secret to the initrd during bootloader
installation, rather than including it in the public Nix store. Nevertheless,
the resulting initrd and EFI partition are **not encrypted**. On tracy the
`/boot` mount has been made root-only, as it already was on kitty; physical
access or another privileged OS can still extract the dedicated key.

## Deploy and test locally first

```sh
sudo nixos-rebuild build --flake .#tracy  # use .#kitty on kitty
sudo nixos-rebuild boot --flake .#tracy   # use .#kitty on kitty
```

Test the next boot with a local keyboard and display available, then test the
initrd SSH connection during the LUKS prompt (before entering the passphrase
locally). For a successful first test, keep the local console as fallback.
If a host uses a different Ethernet driver, add it to
`boot.initrd.availableKernelModules`.

## Remote unlock

The client needs the private key corresponding to one of the SSH public keys
listed for `users.users.bernd` in the target host's NixOS configuration.

```sh
ssh -tt -p 2222 root@tracy
# or ssh -tt -p 2222 root@kitty
```

The forced command is `systemd-tty-ask-password-agent --watch`: type the LUKS
passphrase in the terminal when prompted. No arbitrary root shell, port
forwarding, or agent forwarding is permitted. After the successful unlock the
initrd completes, the connection closes, and ordinary SSH is available:

```sh
ssh bernd@tracy     # port 22, normal NixOS
```

Use an IP address if the initrd DHCP network is not discoverable via DNS/mDNS.
No cable means no initrd SSH, but **must not delay the local unlock** because
initrd `wait-online` is disabled. For access from outside the LAN, connect to
an already available VPN on the *router*, not a VPN inside NixOS; do not
expose port 2222 to the public Internet.

### Security notes

- The initrd host key is separate from the stage-2 SSH key; SSH will use
  independent known-hosts identities for ports 2222 and 22.
- `nixos-rebuild switch`/`boot` must run on a machine with access to the
  correct host-specific key path. Do not cross-build by silently substituting
  another computer's host key.
- The LUKS password is **not** saved in Nix or the repo, and the initrd key
  does **not** unlock the vault by itself.
- This is not a substitute for Secure Boot / measured boot; an attacker who
  can modify the unencrypted initrd can tamper with the password prompt.
