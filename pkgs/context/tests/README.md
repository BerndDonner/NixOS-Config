# Portable ConTeXt integration tests

The Nix sandbox derivation runs both sources below against the extracted
portable engine before producing `context-lmtx-ready.tar.xz`:

- `smoke.tex`: installed fonts, `\unit` and MetaPost/MetaFun.
- `modules.tex`: imports both pinned third-party modules (`filter` and `vim`).

These smoke tests intentionally do not establish numerical or typographic
correctness of all unit expressions. The planned upstream `\unit` modifications
require a separate exhaustive text/math/MetaPost regression suite.
