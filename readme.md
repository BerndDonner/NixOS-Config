# My NixOS Configuration

Welcome to my NixOS configuration repository. Here you will find various configurations and packages that I use with NixOS. 

## LuaMetaTeX Package

One of the highlights of this repository is the LuaMetaTeX package found in the `Packages` subdirectory. This Nix package is based on the excellent work of Marco Feltmann. You can find the original source [here](https://github.com/marcofeltmann/luametatex.nix/blob/master/context.nix).

### Key Features

- **Up-to-Date Repository**: The package leverages the current repository from [contextgarden](https://github.com/contextgarden/context).
- **Essential Fonts**: It utilizes the zip file from [Pragma ADE](http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip) to provide necessary fonts for the LMTX version of ConTeXt.

### Why LuaMetaTeX?

The ConTeXt typesetting system, primarily developed by Hans Hagen, offers a significantly leaner and more structured codebase compared to the LaTeX ecosystem. In my experience, ConTeXt provides superior functionality and efficiency.

## Personal NixOS Configuration

This repository also serves as a backup for my personal NixOS configuration. Please note that it may not be optimal due to my relative inexperience with NixOS. However, it reflects my current setup and customization efforts.

## Rebuilding the Configuration

To apply the configuration, use the following command:
```sh
nixos-rebuild switch
```

Feel free to explore and adapt any parts of this configuration to suit your own needs.

