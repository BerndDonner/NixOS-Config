{ stdenvNoCC
, contextPackage
, contextRevision
, coreutils
, findutils
, gnugrep
, gnutar
, xz
, python3
}:

# Optional reference sources from the SAME patched package as .#context and
# .#context-sandbox-patched. No second checkout or extra engine build.
# The local NixOS package retains the complete, unmodified documentation.
stdenvNoCC.mkDerivation {
  pname = "context-lmtx-docs";
  inherit (contextPackage) version;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ coreutils findutils gnugrep gnutar xz python3 ];

  installPhase = ''
    runHook preInstall

    source_doc="${contextPackage}/tex/texmf-context/doc"
    root="$TMPDIR/context-lmtx-docs"
    mkdir -p "$root/doc"
    cp -aL "$source_doc/." "$root/doc/"
    chmod -R u+w "$root/doc"

    # Keep MkXL/LMTX and MkIV source material and supporting assets. Old MkII
    # files and pre-rendered PDFs do not help the source reference archive.
    find "$root/doc" -type f -iname '*.pdf' -delete
    find "$root/doc" -type d -name mkii -prune -exec rm -rf -- '{}' +
    find "$root/doc" -type f -name '*.mkii' -delete

    # The reference material must contain real MkXL manuals, not just an
    # empty archive or an incomplete copy of the documentation tree.
    test -s "$root/doc/context/sources/documents/general/manuals/mkxl/beyond/beyond.tex"
    test -d "$root/doc/context/sources/documents/general/manuals/mkiv"
    if find "$root/doc" \( -type f -iname '*.pdf' -o -type d -name mkii \) \
        -print -quit | grep -q .; then
      echo 'PDF or MkII documentation remains in context-docs' >&2
      exit 1
    fi

    export CTX_DOC_ROOT="$root"
    export CTX_SOURCE_DOC="$source_doc"
    export CTX_REVISION='${contextRevision}'
    export CTX_VERSION='${contextPackage.version}'
    ${python3}/bin/python3 ${./.}/make-docs-manifest.py

    # Deterministic archive, a .tar.xz FILE like .#context-sandbox-patched.
    tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner \
      -C "$TMPDIR" -cJf "$out" context-lmtx-docs
    tar -tJf "$out" > "$TMPDIR/docs-contents.txt"
    grep -Fxq 'context-lmtx-docs/manifest.json' "$TMPDIR/docs-contents.txt"
    grep -Fxq 'context-lmtx-docs/doc/context/sources/documents/general/manuals/mkxl/beyond/beyond.tex' \
      "$TMPDIR/docs-contents.txt"

    runHook postInstall
  '';

  meta = {
    description = "ConTeXt LMTX/MkIV documentation sources without PDFs or MkII";
    platforms = [ "x86_64-linux" ];
  };
}
