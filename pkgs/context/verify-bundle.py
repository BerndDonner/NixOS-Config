#!/usr/bin/env python3
"""Verify engine identity and LMTX runtime assets in a portable archive.

Run after building both derivations:
  python3 pkgs/context/verify-bundle.py result-context result-sandbox

The bundles may contain different wrappers and dynamic library paths. This
verifies the engine and the complete retained TeX assets, including filter and vim.
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


EXCLUDED = [
    'texmf-context/doc',
    'texmf-context/tex/context/**/mkii',
    'texmf-context/tex/context/**/*.mkii',
]


def is_excluded(relative: str) -> bool:
    parts = relative.split('/')
    if parts[:2] == ['texmf-context', 'doc']:
        return True
    if parts[:3] == ['texmf-context', 'tex', 'context']:
        return 'mkii' in parts[3:-1] or relative.endswith('.mkii')
    return False


def sha_tree(path: Path, *, prune: bool = False) -> str:
    hasher = hashlib.sha256()
    for child in sorted(p for p in path.rglob("*") if p.is_file()):
        relative = child.relative_to(path).as_posix()
        if prune and is_excluded(relative):
            continue
        if relative in ("texmf-linux-64/bin/luametatex",
                        "texmf-linux-64/bin/luametatex.bin",
                        "texmf-linux-64/bin/mtxrun",
                        "texmf-linux-64/bin/context"):
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
        assert manifest['schema_version'] == 2, 'Unexpected manifest schema'
        assert manifest['excluded'] == EXCLUDED, 'Unexpected pruning policy'
        local_engine = context_package / "tex/texmf-linux-64/bin/luametatex"
        bundled_engine = bundled / "tex/texmf-linux-64/bin/luametatex.bin"
        for name in ("mtxrun", "context"):
            local_link = context_package / "tex/texmf-linux-64/bin" / name
            portable_link = bundled / "tex/texmf-linux-64/bin" / name
            assert local_link.is_symlink() and local_link.readlink() == Path("luametatex"), \
                f"Unexpected local entrypoint: {name}"
            assert portable_link.is_symlink() and portable_link.readlink() == Path("luametatex"), \
                f"Unexpected portable entrypoint: {name}"
        expected_engine = sha_file(local_engine)
        source_tex = context_package / 'tex'
        expected_source_tree = sha_tree(source_tex)
        expected_runtime_tree = sha_tree(source_tex, prune=True)
        assert expected_engine == sha_file(bundled_engine) == manifest["engine_sha256"], \
            "LuaMetaTeX engine differs"
        assert expected_source_tree == manifest['source_tex_tree_sha256'], \
            'Original desktop TeX tree differs'
        assert expected_runtime_tree == sha_tree(bundled / 'tex') == manifest['tex_tree_sha256'], \
            'Retained LMTX runtime assets differ'
        print("OK: identical LuaMetaTeX engine and retained LMTX runtime assets")
        print("ConTeXt revision:", manifest["context_revision"])
        print("Engine SHA-256:", expected_engine)
        print("Portable TeX tree SHA-256:", expected_runtime_tree)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify-bundle.py <context-package> <sandbox.tar.xz>")
    verify(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
