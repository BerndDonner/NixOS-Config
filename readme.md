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

ConTeXt is built **exclusively through the root flake**. The productive
`.#context` package (and `overlays.context` / `pkgs.contextLmtx`) contains our
Math/Glue patch. Its Nix package version is `2026.10.25-p1`; the output of
`context --version` displays that local marker without modifying ConTeXt's
internal format version.

Three engine versions can be built independently:

| Output | Source | Engine patch |
| --- | --- | --- |
| `.#context` | `5751e396` (25 Oct 2026) | Math/Glue `noautobreak` patch; **default** |
| `.#context-2024` | `0d2ec448` (1 Nov 2024) | none |
| `.#context-upstream` | `445076e5` (29 Oct 2026) | none |

The only portable output is `.#context-sandbox-patched`, derived from precisely
the same package as `.#context`. The separate `.#context-docs` output provides
reference documentation. Old Hans/trace outputs and `context-patched` aliases
have been deleted. The parameterized LuaMetaTeX derivation still supports
future independent engine patch stacks.

### 🔄 Updating ConTeXt independently of NixOS

The source pins are independent of `nixpkgs` and Home Manager:
`context-src` is the locked productive revision; `context-2024-src` and
`context-upstream-src` specify immutable comparison commits. The pinned
`filter-src` input at `ca120d8` supplies filter and Vim, including the upstream
writability fix. No local filter patch is needed. The original `texmf.zip`
fixed-output hash stays unchanged.

After applying this patch, resolve the three **new** inputs in `flake.lock`
(they use URLs with fixed commit IDs) and commit the lock file:

```bash
nix flake lock
git diff -- flake.lock

nix build .#context -o result-context -L
nix build .#context-2024 -o result-context-2024 -L
nix build .#context-upstream -o result-context-upstream -L
./result-context/bin/context --version

nix build .#context-sandbox-patched -o result-sandbox-patched -L
nix develop .#context -c python3 \
  pkgs/context/verify-bundle.py result-context result-sandbox-patched

# Manual host integration test (kitty/tracy only):
pkgs/context/tests/check-system-carlito.sh ./result-context/bin/context
```

A successful package build is **not** proof of typographic correctness.
Use the independent `context-testsuite` for Math/Glue/Penalty regression
cases and representative teaching PDFs before accepting a new source pin.
Do not run `nix flake update` without a target when only a ConTeXt source
change is intended.

ConTeXt is used through consumer development shells rather than being
installed globally. A consumer such as `unterrichts-texte` should now choose
`nixos-config.packages.${system}.context` instead of the deleted
`context-patched` output. After validating and publishing this change,
update that consumer's own locked `nixos-config` input deliberately.

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
