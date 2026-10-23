#!/usr/bin/env python3
"""Write and verify the manifest for the optional ConTeXt documentation archive.

Uses only Python stdlib; also imported by verify-docs.py so pruning policies
and checksum semantics cannot silently drift between builder and verifier.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path


EXCLUDED = ["**/*.pdf", "**/mkii/**", "**/*.mkii"]


def excluded(relative: Path) -> bool:
    return (
        relative.suffix.lower() == ".pdf"
        or relative.suffix == ".mkii"
        or "mkii" in relative.parts
    )


def sha_tree(path: Path, *, prune: bool = False) -> tuple[str, int]:
    """Hash relative file names + SHA256 file contents, in sorted order."""
    hasher = hashlib.sha256()
    count = 0
    for child in sorted(p for p in path.rglob("*") if p.is_file()):
        relative = child.relative_to(path)
        if prune and excluded(relative):
            continue
        name = relative.as_posix().encode("utf-8")
        hasher.update(len(name).to_bytes(8, "big"))
        hasher.update(name)
        file_hash = hashlib.sha256()
        with child.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                file_hash.update(chunk)
        hasher.update(file_hash.digest())
        count += 1
    return hasher.hexdigest(), count


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
