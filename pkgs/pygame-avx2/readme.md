# 🐍 Pygame (AVX2 Enabled, Nix Flake Package)

## 🧱 Building

To build this package as part of your main Nix flake:

```sh
nix build .#pygame-avx2
```

or simply:

```sh
nix build .
```

This produces a Pygame installation built with AVX2 optimizations inside `./result`.

To see detailed logs or trace errors:

```sh
nix build .#pygame-avx2 --show-trace
```

---

## 🚀 Testing

You can open a test shell and run the included demo:

```sh
cd pygame-avx2
nix build        # builds and installs pygame-avx2 package
nix develop      # opens test shell
python3 -m pygame.examples.aliens
```

This runs the classic **“Aliens”** demo to confirm that Pygame is correctly built and using AVX2 optimizations.

---

## 🗂 Structure

| File | Description |
|------|--------------|
| `flake.nix` | Flake entry point defining `pygame-avx2` package and devShell |
| `pygame-avx2.nix` | Nix derivation building Pygame with AVX2 enabled |
| *(no `default.nix`)* | This is a pure flake setup |

The package is exposed as:
```
packages.x86_64-linux.pygame-avx2
```

---

## 🧾 Notes

- The package builds Pygame **from source** with `PYGAME_DETECT_AVX2=1` set.  
- The setup script is patched automatically to fix the `distutils.spawn` import.  
- This build may offer better performance on CPUs supporting AVX2.  
- To update the package later:
  1. Edit version and hash in `pygame-avx2.nix`
  2. Run:
     ```sh
     nix flake update
     ```

---

**Upstream:** [pygame/pygame](https://github.com/pygame/pygame)  
**Author:** Bernd Donner
