{ stdenvNoCC
, lib
, contextPackage
, glibc
, coreutils
, gnutar
, xz
, gawk
, gnugrep
, python3
}:

# Portable x86_64-linux artifact from the EXACT package used by Home Manager.
# No separate ConTeXt download, checkout, or engine build takes place here.
assert stdenvNoCC.hostPlatform.system == "x86_64-linux";
stdenvNoCC.mkDerivation {
  pname = "context-lmtx-sandbox";
  inherit (contextPackage) version;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ coreutils gnutar xz gawk gnugrep python3 ];

  installPhase = ''
    runHook preInstall

    root="$TMPDIR/context-lmtx-ready"
    mkdir -p "$root/tex" "$root/glibc"
    # All files, including texmf.zip, filter and vim, come from the shared
    # Nix derivation. Do not rebuild or download anything here.
    cp -aL ${contextPackage}/tex/. "$root/tex/"
    chmod -R u+w "$root"

    bin="$root/tex/texmf-linux-64/bin"
    mv "$bin/luametatex" "$bin/luametatex.bin"
    cp ${./portable-engine.sh} "$bin/luametatex"
    chmod 755 "$bin/luametatex"

    # Discover the actual ELF dependencies of this *specific* build rather
    # than copying the whole glibc closure (including unused gconv modules).
    # Use glibc's own loader so the output remains usable without /nix/store.
    engine="$bin/luametatex.bin"
    loader="${glibc}/lib/ld-linux-x86-64.so.2"
    test -f "$loader"
    cp -L "$loader" "$root/glibc/ld-linux-x86-64.so.2"
    "$loader" --list "$engine" > "$TMPDIR/engine-libs.txt"
    if grep -q 'not found' "$TMPDIR/engine-libs.txt"; then
      cat "$TMPDIR/engine-libs.txt" >&2
      echo 'Unresolved LuaMetaTeX shared library' >&2
      exit 1
    fi
    awk '$2 == "=>" && $3 ~ /^\// {print $3}
         $1 ~ /^\// {print $1}' "$TMPDIR/engine-libs.txt" \
      | sort -u > "$TMPDIR/library-paths.txt"
    while IFS= read -r library; do
      test -f "$library"
      name="$(basename "$library")"
      if test -e "$root/glibc/$name"; then
        cmp -s "$library" "$root/glibc/$name" || {
          echo "Conflicting ELF dependency: $name" >&2
          exit 1
        }
      else
        cp -L "$library" "$root/glibc/$name"
      fi
    done < "$TMPDIR/library-paths.txt"

    cp ${./context-local.sh} "$root/context-local.sh"
    chmod 755 "$root/context-local.sh"

    # Checksums of the installed engine and complete TeX tree. The resulting
    # manifest is embedded in the archive and travels with each Hosted run.
    export CTX_BUNDLE_ROOT="$root"
    export CTX_REVISION='${contextPackage.contextRevision or "unknown"}'
    export CTX_VERSION='${contextPackage.version}'
    ${python3}/bin/python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
root = Path(os.environ['CTX_BUNDLE_ROOT'])
def sha_file(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), bytes()):
            h.update(chunk)
    return h.hexdigest()
def sha_tree(path):
    h = hashlib.sha256()
    for child in sorted(p for p in path.rglob('*') if p.is_file()):
        relative = child.relative_to(path).as_posix()
        # The portable engine is renamed and wrapped. Verify its binary
        # separately, not as part of the otherwise identical TeX tree.
        if relative in ('texmf-linux-64/bin/luametatex',
                        'texmf-linux-64/bin/luametatex.bin'):
            continue
        name = relative.encode()
        h.update(len(name).to_bytes(8, 'big'))
        h.update(name)
        h.update(bytes.fromhex(sha_file(child)))
    return h.hexdigest()
manifest = dict(
    schema_version=1,
    context_revision=os.environ['CTX_REVISION'],
    package_version=os.environ['CTX_VERSION'],
    architecture='x86_64-linux',
    engine_sha256=sha_file(root/'tex/texmf-linux-64/bin/luametatex.bin'),
    tex_tree_sha256=sha_tree(root/'tex'),
    modules=['filter', 'vim'],
)
(root/'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(root/'context-local.sh').write_text(
    (root/'context-local.sh').read_text().replace('@BUNDLE_HASH@', manifest['tex_tree_sha256'][:16]))
PY

    # Both portable scripts intentionally use #!/usr/bin/env bash, which is
    # absent inside an isolated Nix builder. Rewrite JUST those two shebangs
    # for build-time smoke tests; restore portable ones before archiving.
    # Do not patch the host ConTeXt installPhase or the installed TeX tree.
    patchShebangs --host "$bin/luametatex" "$root/context-local.sh"

    # Regression gate inside the Nix build: loader, fonts, MetaPost, modules.
    test -f "$root/tex/texmf-context/tex/context/third/filter/t-filter.mkxl"
    test -f "$root/tex/texmf-context/tex/context/third/vim/t-syntax-highlight.mkxl"
    "$bin/luametatex" --version > "$TMPDIR/engine-version.txt"
    export HOME="$TMPDIR/home"
    export TEXMFCACHE="$TMPDIR/cache"
    mkdir -p "$HOME" "$TMPDIR/smoke"
    cp ${./tests/smoke.tex} "$TMPDIR/smoke/smoke.tex"
    cp ${./tests/modules.tex} "$TMPDIR/smoke/modules.tex"
    (
      cd "$TMPDIR/smoke"
      "$root/context-local.sh" --once smoke.tex > "$TMPDIR/smoke.log" 2>&1 || {
        cat "$TMPDIR/smoke.log" >&2
        exit 1
      }
      test -s smoke.pdf
      "$root/context-local.sh" --once modules.tex > "$TMPDIR/modules.log" 2>&1 || {
        cat "$TMPDIR/modules.log" >&2
        exit 1
      }
      test -s modules.pdf
    )

    # Remove Nix-store interpreter paths from the portable launchers. In the
    # final archive, /usr/bin/env resolves bash on the target Linux machine.
    sed -i '1c#!/usr/bin/env bash' "$bin/luametatex" "$root/context-local.sh"
    test "$(head -n 1 "$bin/luametatex")" = '#!/usr/bin/env bash'
    test "$(head -n 1 "$root/context-local.sh")" = '#!/usr/bin/env bash'

    # $out is an actual .tar.xz FILE, compatible with context-agent's archive
    # uploader. GNU tar reproducibility flags keep rebuilds stable.
    tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner \
        -C "$TMPDIR" -cJf "$out" context-lmtx-ready
    # Avoid tar receiving SIGPIPE under pipefail from an early grep -q exit.
    tar -tJf "$out" > "$TMPDIR/archive-contents.txt"
    grep -Fxq 'context-lmtx-ready/context-local.sh' "$TMPDIR/archive-contents.txt"
    runHook postInstall
  '';

  meta = {
    description = "Portable ConTeXt LMTX bundle from the same Nix derivation as the desktop package";
    platforms = [ "x86_64-linux" ];
  };
}
