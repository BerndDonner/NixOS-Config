#!/usr/bin/env python3
"""Write the portable runtime manifest (launcher substitution belongs to Nix)."""
import json
import os
from pathlib import Path
from manifest_common import RUNTIME_EXCLUDED, sha_file, runtime_tree as sha_tree


def main() -> None:
    root = Path(os.environ['CTX_BUNDLE_ROOT'])
    manifest = dict(
        schema_version=2,
        source_tex_tree_sha256=sha_tree(Path(os.environ['CTX_SOURCE_TEX'])),
        excluded=RUNTIME_EXCLUDED,
        context_revision=os.environ['CTX_REVISION'],
        package_version=os.environ['CTX_VERSION'],
        architecture='x86_64-linux',
        engine_sha256=sha_file(root/'tex/texmf-linux-64/bin/luametatex.bin'),
        tex_tree_sha256=sha_tree(root/'tex'),
        modules=['filter', 'vim'],
    )
    (root/'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(manifest['tex_tree_sha256'][:16])


if __name__ == "__main__":
    main()
