#!/usr/bin/env python3
"""Write and verify the manifest for the optional ConTeXt documentation archive.

Uses manifest_common for shared pruning policies and checksum semantics.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from manifest_common import DOCS_EXCLUDED as EXCLUDED, docs_tree as sha_tree


def main() -> None:
    source = Path(os.environ["CTX_SOURCE_DOC"])
    root = Path(os.environ["CTX_DOC_ROOT"])
    original_hash, original_count = sha_tree(source)
    expected_hash, expected_count = sha_tree(source, prune=True)
    retained_hash, retained_count = sha_tree(root / "doc")
    if (expected_hash, expected_count) != (retained_hash, retained_count):
        raise SystemExit("Documentation source projection differs from Nix package")

    manifest = {
        "schema_version": 1,
        "context_revision": os.environ["CTX_REVISION"],
        "package_version": os.environ["CTX_VERSION"],
        "excluded": EXCLUDED,
        "source_doc_tree_sha256": original_hash,
        "source_file_count": original_count,
        "docs_tree_sha256": retained_hash,
        "docs_file_count": retained_count,
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
