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
