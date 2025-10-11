# 🧰 Boot.dev CLI (Nix Flake Package)

## 🧱 Building

To build this package as part of your main Nix flake:

```sh
nix build .#bootdev-cli
```

or simply:

```sh
nix build .
```

This produces the Boot.dev CLI binary in `./result/bin/bootdev`.

To see build details or trace errors:

```sh
nix build .#bootdev-cli --show-trace
```

---

## 🚀 Running

You can run the CLI directly without building explicitly:

```sh
nix run . -- --version
```

or

```sh
nix run .#bootdev-cli -- help
```

(Everything after `--` is passed to the Boot.dev program.)

---

## 🗂 Structure

| File | Description |
|------|--------------|
| `flake.nix` | Flake entry point, defines `bootdev-cli` package |
| `bootdev-cli.nix` | Nix derivation using `buildGoModule` |
| *(no `default.nix`)* | This is a pure flake setup |

The package is exposed as:
```
packages.x86_64-linux.bootdev-cli
```

---

## 🧾 Notes

- The binary in the Nix store is immutable – Boot.dev’s self-update feature is harmless but ineffective.  
- The build is fully reproducible and self-contained.  
- To update the package later:
  1. Edit the version and hashes in `bootdev-cli.nix`
  2. Run:
     ```sh
     nix flake update
     ```

---

**Version:** 1.20.4  
**Upstream:** [bootdotdev/bootdev](https://github.com/bootdotdev/bootdev)  
**Author:** Bernd Donner
