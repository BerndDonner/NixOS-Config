#!/usr/bin/env python3
"""Verify engine identity and LMTX runtime assets in a portable archive.

Run after building both derivations:
  python3 pkgs/context/verify-bundle.py result-context result-sandbox

The bundles may contain different wrappers and dynamic library paths. This
verifies the engine and the complete retained TeX assets, including filter and vim.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tarfile
import tempfile

from manifest_common import (
    RUNTIME_EXCLUDED as EXCLUDED, sha_file, runtime_tree as sha_tree, verify_metadata,
)


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
        verify_metadata(context_package, manifest)
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
