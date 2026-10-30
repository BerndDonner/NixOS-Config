"""Packaging tests without Nix or ConTeXt; run with unittest discover."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from manifest_common import docs_tree, runtime_tree, docs_excluded, runtime_excluded

# Includes Unicode, binary content, a symlink, engine exclusions and both policies.
FILES = {
    'texmf-context/tex/context/base/mkxl/a.tex': b'alpha\n',
    'texmf-context/tex/context/base/mkiv/b.lua': b'beta\x00',
    'texmf-context/tex/context/base/mkii/old.tex': b'old',
    'texmf-context/tex/context/base/old.mkii': b'legacy',
    'texmf-context/doc/Guide.PDF': b'pdf',
    'texmf-context/doc/guide.tex': b'doc',
    'texmf-linux-64/bin/luametatex': b'engine',
    'texmf-linux-64/bin/context.lmt': b'runner',
    'fonts/ü.otf': b'font',
}


class Manifests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        # Deliberately no version in directory name: metadata is authoritative.
        self.package = self.root / 'package'
        self.tex = self.package / 'tex'
        for name, data in FILES.items():
            path = self.tex / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        (self.tex / 'alias').symlink_to('fonts/ü.otf')
        self.metadata = dict(schema_version=1, package_version='2026.10.25-p1',
                             context_revision='5751e39641a5' + '0' * 28,
                             patch_label='math-glue-noautobreak')
        metadata_path = self.package / 'share/context/build-info.json'
        metadata_path.parent.mkdir(parents=True)
        metadata_path.write_text(json.dumps(self.metadata))
        self.env = dict(os.environ, CTX_REVISION=self.metadata['context_revision'],
                        CTX_VERSION=self.metadata['package_version'])

    def command(self, script, *args, env=None, success=True):
        result = subprocess.run([sys.executable, str(SCRIPTS / script), *map(str, args)],
                                env=env, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_historical_hashes(self):
        # Fixed values obtained from the pre-refactor implementations.
        self.assertEqual(runtime_tree(self.tex),
                         '3febb60c4b8c2a3e833994483c6ac3f0a9052fabe49f19e5fc697757bc41f458')
        self.assertEqual(runtime_tree(self.tex, prune=True),
                         '85405aace3912a7c16b33c26fd6147bee7e96b5e4b389b2f9d33eda3d5208755')
        self.assertEqual(docs_tree(self.tex),
                         ('3cd9716030b2849354ae8547a32aeb7d0777731c6d2a3c075121f9bf85c53525', 10))
        self.assertEqual(docs_tree(self.tex, prune=True),
                         ('4a6fd71d8ed7101ab10d5e3d82863ee6827aa988e02e24bcfdc98c1b22ed1b05', 7))

    def test_empty_tree(self):
        empty = self.root / 'empty'
        empty.mkdir()
        digest = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        self.assertEqual(runtime_tree(empty), digest)
        self.assertEqual(docs_tree(empty), (digest, 0))

    def check_archive(self, kind):
        docs = kind == 'docs'
        bundle = self.root / ('context-lmtx-docs' if docs else 'context-lmtx-ready')
        if docs:
            source = self.tex / 'texmf-context/doc'
            target = bundle / 'doc'
            self.env.update(CTX_DOC_ROOT=str(bundle), CTX_SOURCE_DOC=str(source))
        else:
            source = self.tex
            target = bundle / 'tex'
            for name in ('mtxrun', 'context'):
                (source / 'texmf-linux-64/bin' / name).symlink_to('luametatex')
            self.env.update(CTX_BUNDLE_ROOT=str(bundle), CTX_SOURCE_TEX=str(source))
        shutil.copytree(source, target, symlinks=True)
        for path in target.rglob('*'):
            rel = path.relative_to(target)
            if path.is_file() and (docs_excluded(rel) if docs else runtime_excluded(rel.as_posix())):
                path.unlink()
        if not docs:
            engine = target / 'texmf-linux-64/bin/luametatex'
            engine.rename(engine.with_name('luametatex.bin'))
            engine.write_text('portable wrapper')
        self.command(f'make-{kind}-manifest.py', env=self.env)
        archive = self.root / 'archive.tar.xz'

        def verify(success=True):
            with tarfile.open(archive, 'w:xz') as tar:
                tar.add(bundle, arcname=bundle.name)
            self.command(f'verify-{kind}.py', self.package, archive, success=success)

        verify()
        # Same content with false provenance must fail, for p1 and arbitrary names.
        manifest_path = bundle / 'manifest.json'
        original = json.loads(manifest_path.read_text())
        for key in ('package_version', 'context_revision'):
            changed = dict(original, **{key: 'wrong'})
            manifest_path.write_text(json.dumps(changed))
            verify(False)
        manifest_path.write_text(json.dumps(original))
        retained = target / ('guide.tex' if docs else 'fonts/ü.otf')
        retained.write_bytes(b'changed content')
        verify(False)
        retained.unlink()
        verify(False)

    def test_docs_archive(self):
        self.check_archive('docs')

    def test_runtime_archive(self):
        self.check_archive('bundle')


if __name__ == '__main__':
    unittest.main()
