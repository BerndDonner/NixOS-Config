"""Stable manifest checksums and explicitly separate archive pruning policies."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from collections.abc import Callable


def sha_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), bytes()):
            hasher.update(chunk)
    return hasher.hexdigest()


RUNTIME_EXCLUDED = [
    'texmf-context/doc',
    'texmf-context/tex/context/**/mkii',
    'texmf-context/tex/context/**/*.mkii',
]


def runtime_excluded(relative: str) -> bool:
    parts = relative.split('/')
    if parts[:2] == ['texmf-context', 'doc']:
        return True
    if parts[:3] == ['texmf-context', 'tex', 'context']:
        return 'mkii' in parts[3:-1] or relative.endswith('.mkii')
    return False


DOCS_EXCLUDED = ["**/*.pdf", "**/mkii/**", "**/*.mkii"]


def docs_excluded(relative: Path) -> bool:
    return (
        relative.suffix.lower() == ".pdf"
        or relative.suffix == ".mkii"
        or "mkii" in relative.parts
    )


ENGINE_PATHS = {
    "texmf-linux-64/bin/luametatex", "texmf-linux-64/bin/luametatex.bin",
    "texmf-linux-64/bin/mtxrun", "texmf-linux-64/bin/context",
}


def hash_tree(path: Path, skip: Callable[[Path], bool]) -> tuple[str, int]:
    """Hash sorted names (8-byte length prefix) and binary SHA-256 digests."""
    hasher = hashlib.sha256()
    count = 0
    for child in sorted(p for p in path.rglob("*") if p.is_file()):
        relative = child.relative_to(path)
        if skip(relative):
            continue
        name = relative.as_posix().encode("utf-8")
        hasher.update(len(name).to_bytes(8, "big"))
        hasher.update(name)
        hasher.update(bytes.fromhex(sha_file(child)))
        count += 1
    return hasher.hexdigest(), count


def runtime_tree(path: Path, *, prune: bool = False) -> str:
    return hash_tree(path, lambda rel: rel.as_posix() in ENGINE_PATHS
                     or (prune and runtime_excluded(rel.as_posix())))[0]


def docs_tree(path: Path, *, prune: bool = False) -> tuple[str, int]:
    return hash_tree(path, lambda rel: prune and docs_excluded(rel))


def verify_metadata(context_package: Path, manifest: dict) -> None:
    metadata = json.loads((context_package / "share/context/build-info.json").read_text())
    assert metadata["schema_version"] == 1, "Unexpected package metadata schema"
    for key in ("context_revision", "package_version"):
        assert manifest[key] == metadata[key], f"Archive and local package {key} differ"
