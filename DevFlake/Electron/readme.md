# Developing with Electron on NixOS

## 1. That is the way to develop with Electron on NixOS

To get started with Electron development on NixOS, use the following commands:

```bash
npm install --save @electron/remote
electron .
```

## 2. Less important info

### 2.1. NPM Configuration with Language Servers

I use npm with a bunch of language servers and leverage npm’s prefix setting for global package installations:

```bash
npm config set prefix "${HOME}/.cache/npm/global"
mkdir -p "${HOME}/.cache/npm/global"
```

After setting this up, you can run `npm install -g <pkg>` as usual.

### 2.2. Fixing Vulkan Driver Warnings

To get rid of Vulkan driver warnings, use the following command:

```bash
export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json
```

### 2.3. Electron on NixOS (Disabling Sandbox)

This does not work on NixOS without deactivating the sandbox:

```bash
nix-shell -p electron
npm install
```
