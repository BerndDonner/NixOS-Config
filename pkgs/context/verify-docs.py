#!/usr/bin/env python3
"""Verify optional docs.tar.xz against the same local ConTeXt derivation.

  python3 pkgs/context/verify-docs.py result-context result-docs
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tarfile
import tempfile

import runpy


# The build and verifier share the exact same pruning/checksum policy.
module = runpy.run_path(str(Path(__file__).with_name("make-docs-manifest.py")))


def verify(context_package: Path, archive: Path) -> None:
    source = context_package / "tex/texmf-context/doc"
    with tempfile.TemporaryDirectory(prefix="context-docs-verify-") as temp:
        destination = Path(temp)
        with tarfile.open(archive, "r:xz") as tar:
            names = tar.getnames()
            assert names and all(
                n == "context-lmtx-docs" or n.startswith("context-lmtx-docs/")
                for n in names
            ), "Unexpected documentation archive layout"
            tar.extractall(destination, filter="data")
        bundle = destination / "context-lmtx-docs"
        manifest = json.loads((bundle / "manifest.json").read_text())
        assert manifest["schema_version"] == 1, "Unexpected manifest schema"
        assert manifest["excluded"] == module["EXCLUDED"], "Different pruning rules"
        source_hash, source_count = module["sha_tree"](source)
        expected_hash, expected_count = module["sha_tree"](source, prune=True)
        docs_hash, docs_count = module["sha_tree"](bundle / "doc")
        assert (manifest["source_doc_tree_sha256"], manifest["source_file_count"]) == (
            source_hash, source_count
        ), "Full source document tree differs"
        assert (manifest["docs_tree_sha256"], manifest["docs_file_count"]) == (
            expected_hash, expected_count
        ), "Manifest does not match expected source projection"
        assert (docs_hash, docs_count) == (expected_hash, expected_count), \
            "Archive documentation differs from local ConTeXt package"
        assert context_package.resolve().name.endswith(manifest["package_version"]), \
            "Archive and local package versions differ"
        assert manifest["context_revision"].startswith(
            manifest["package_version"].removeprefix("unstable-")
        ), "Revision does not match the local ConTeXt package"
        print("OK: documentation sources and supporting assets match local ConTeXt")
        print("ConTeXt revision:", manifest["context_revision"])
        print("Document files:", docs_count)
        print("Document SHA-256:", docs_hash)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify-docs.py <context-package> <docs.tar.xz>")
    verify(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
