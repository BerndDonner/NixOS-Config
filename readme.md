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

- **Separately pinned sources** – uses a locked revision from [contextgarden/context](https://github.com/contextgarden/context)
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

ConTeXt is built **exclusively through the root flake**. There is no
`default.nix` or separate flake under `pkgs/context/`. `.#context` is the
unpatched variant, and `.#context-patched` includes the local Math/Glue fix.
Neither ConTeXt variant is installed globally or by Home Manager on
`kitty`/`tracy`; development shells select the required package explicitly.

### 🔄 Updating ConTeXt without updating NixOS

ConTeXt is a **separately pinned flake input** named `context-src`. Its Git
revision and NAR hash are stored in the **root** `flake.lock`, next to the
independent `nixpkgs`, `nixpkgs-unstable` and Home Manager inputs. There is no
separate `pkgs/context/flake.lock`.

| Input | Purpose | Update only this input |
| --- | --- | --- |
| `context-src` | ConTeXt LMTX and LuaMetaTeX source | `nix flake update context-src` |
| `nixpkgs` | NixOS 26.05 package set / build tools | `nix flake update nixpkgs` |
| `nixpkgs-unstable` | Selected unstable packages | `nix flake update nixpkgs-unstable` |

From the **NixOS-Config repository root**, try a new ConTeXt revision without
switching the installed NixOS system:

```bash
# Update only ConTeXt's source revision.
nix flake update context-src

# Verify the intended change in the shared lock file.
git diff -- flake.lock

# Build and inspect both package variants (their build-time smoke tests run).
nix build .#context -o result-context-unpatched -L
nix build .#context-patched -o result-context-patched -L
./result-context-patched/bin/context --version

# Build and verify a matching portable archive if you need one.
nix build .#context-sandbox-patched -o result-sandbox-patched -L
nix develop .#context -c python3 \
  pkgs/context/verify-bundle.py result-context-patched result-sandbox-patched

# MANUAL host integration check on kitty/tracy; NOT part of a Nix build:
pkgs/context/tests/check-system-carlito.sh \
  ./result-context-patched/bin/context
```

**Check document output before choosing an update.** A successful Nix build
checks that ConTeXt runs but does not guarantee correct typesetting. The
independent `context-testsuite` repository owns the migrated 12-case and
76-case Math/Glue/Penalty tests and the PDF comparison tools. Run it
**deliberately** against the two build outputs; there is no testsuite
integration or automatic cross-version check in this flake. See
[`pkgs/context/tests/README.md`](./pkgs/context/tests/README.md) for the
commands and expected separation of tests.

After validation, commit the pin:

```bash
git add flake.lock
git commit -m "build(context): update pinned ConTeXt source"
```

**A NixOS system rebuild is not needed to use this ConTeXt update:** the
package is accessed through development shells, not installed as a host
package. Projects such as `unterrichts-texte` update their own locked
`nixos-config` input when they decide to adopt it. Updating `context-src`
does **not** update the locked `nixpkgs` revision or Home Manager. Avoid plain
`nix flake update` when you only want ConTeXt: that updates **all** inputs.

For an unsuccessful, **uncommitted** update, restore the old pin with
`git restore flake.lock` (only if you do not have other lock-file edits to
keep). For committed changes, revert the specific update commit.

`texmf.zip` and `adityam/filter` (including `vim`) are **separately fixed by
hashes** in `pkgs/context/luametatex.nix`; they are not refreshed by this
command. Projects with their own flake, such as `unterrichts-texte`, also
have their own lock of the `nixos-config` input. After committing and pushing
a successful update here, update `nixos-config` in the **consumer project's**
lock file to use the new revision (when using a remote Git input).

For technical details and further tests, see
[`pkgs/context/readme.md`](./pkgs/context/readme.md).

---

## 🏠 Personal NixOS Configuration

This repository also serves as a backup for my personal NixOS and Home-Manager configuration.  
It may not be optimal in every respect, but it reflects my current setup and customization efforts.

### 🔁 Rebuilding the System

To apply changes, rebuild the intended host via the root flake:

```bash
sudo nixos-rebuild switch --flake .#kitty
# or on tracy:
sudo nixos-rebuild switch --flake .#tracy
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

---

## Shared development shells

The public `lib` exports include `mkPythonDevShell`, `mkArduinoDevShell`,
`mkCDevShell`, and `mkElectronDevShell`. For shells that check flake input
revisions, the consuming flake **must** supply its own lockfile path:

```nix
devShells.${system}.default = nixos-config.lib.mkPythonDevShell {
  inherit pkgs;
  inputs = { inherit nixos-config nixpkgs; };
  checkInputs = [ "nixos-config" ];
  flakeLockPath = ./flake.lock;
};
```

The lock path is relative to the **calling flake**, not this repository's
`lib/` directory. A nested flake therefore uses its own `./flake.lock`.
For shells without `checkInputs`, `inputs` and `flakeLockPath` are optional.


## Shared development shells (flake-only)

The helper functions `lib.mkPythonDevShell`, `lib.mkCDevShell`,
`lib.mkContextDevShell`, `lib.mkArduinoDevShell`,
`lib.mkElectronDevShell` and `lib.mkPythonVenvDevShell` are reusable in
projects with their own locked `nixos-config` input.

Every consuming project must pass `inputs = { inherit nixos-config; };`
and `flakeLockPath = ./flake.lock;` to get the **non-blocking** update warning.
The warning checks GitHub's current branch HEAD, respecting an explicit branch
in the input, and caches successful remote results for six hours. If offline,
it skips the check. To override the cache, use `DEVFLAKE_UPDATE_CHECK=force
nix develop`; to skip checks, set `DEVFLAKE_UPDATE_CHECK=off`.
No hook updates a lock file automatically.

The optional command `devflake-update` (available inside each shared DevShell)
updates only `nixos-config`, displays its Git diff, and evaluates the default
DevShell without building packages:

```bash
nix develop
devflake-update
```

**Python**: `pythonPackages = ps: [ ... ]` controls importable modules;
`pythonTools = ps: [ ... ]` adds optional developer modules (e.g. `ipython`,
`black`). Non-Python tools go into `extraPackages`. Bare Python is the default.

**C/C++**: default build system is `make`. Add e.g.
`buildSystems = [ "meson" "ninja" ];`, `debugTools = [ "gdb" ];`,
`utilityTools = [ "git" ];` as needed. Libraries remain in `extraBuildInputs`.

**ConTeXt**: `extraPackages` permits adding Python (e.g. PyMuPDF) without
`overrideAttrs`.

**Arduino**: the shared shell uses the independently pinned
[`yabu76/tio`](https://github.com/yabu76/tio/tree/master_this_fork)
package instead of picocom/minicom. Update with `nix flake update tio-src` in
NixOS-Config, then build `nix build .#tio-fork`. Following the new template
in dependent repositories requires `nix flake update nixos-config` there.
