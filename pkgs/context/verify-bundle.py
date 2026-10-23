#!/usr/bin/env python3
"""Verify exact ConTeXt engine and TeX tree identity in a portable archive.

Run after building both derivations:
  python3 pkgs/context/verify-bundle.py result-context result-sandbox

The bundles may contain different wrappers and dynamic library paths. This
verifies the engine and all shipped TeX assets, including filter and vim.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tarfile
import tempfile


def sha_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), bytes()):
            hasher.update(chunk)
    return hasher.hexdigest()


def sha_tree(path: Path) -> str:
    hasher = hashlib.sha256()
    for child in sorted(p for p in path.rglob("*") if p.is_file()):
        relative = child.relative_to(path).as_posix()
        if relative in ("texmf-linux-64/bin/luametatex",
                        "texmf-linux-64/bin/luametatex.bin"):
            continue
        name = relative.encode()
        hasher.update(len(name).to_bytes(8, "big"))
        hasher.update(name)
        hasher.update(bytes.fromhex(sha_file(child)))
    return hasher.hexdigest()


def verify(context_package: Path, archive: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="context-bundle-verify-") as temp:
        destination = Path(temp)
        with tarfile.open(archive, "r:xz") as source:
            names = source.getnames()
            assert names and all(name.startswith("context-lmtx-ready/") or
                                 name == "context-lmtx-ready" for name in names), \
                "Unexpected archive layout"
            source.extractall(destination, filter="data")
        bundled = destination / "context-lmtx-ready"
        manifest = json.loads((bundled / "manifest.json").read_text())
        local_engine = context_package / "tex/texmf-linux-64/bin/luametatex"
        bundled_engine = bundled / "tex/texmf-linux-64/bin/luametatex.bin"
        expected_engine = sha_file(local_engine)
        expected_tree = sha_tree(context_package / "tex")
        assert expected_engine == sha_file(bundled_engine) == manifest["engine_sha256"], \
            "LuaMetaTeX engine differs"
        assert expected_tree == sha_tree(bundled / "tex") == manifest["tex_tree_sha256"], \
            "ConTeXt TeX/font tree differs"
        print("OK: identical LuaMetaTeX engine and full TeX tree")
        print("ConTeXt revision:", manifest["context_revision"])
        print("Engine SHA-256:", expected_engine)
        print("TeX tree SHA-256:", expected_tree)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify-bundle.py <context-package> <sandbox.tar.xz>")
    verify(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
