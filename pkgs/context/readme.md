# 📄 Updated README

## 🧱 Building LuaMetaTeX (ConTeXt LMTX)

To build this package as part of your main Nix flake:

```sh
nix build .#context
```

This produces the ConTeXt (LMTX) engine in ./result/bin/,
including the commands luametatex, mtxrun, and context.

For detailed error information during the build, add:

```
nix build .#context --show-trace
```

