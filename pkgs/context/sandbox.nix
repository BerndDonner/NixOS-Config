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
, vim
}:

# Portable x86_64-linux artifact from exactly the supplied contextPackage.
# The regular variant is also the package used by Home Manager. No second
# ConTeXt download, checkout or compilation takes place here.
assert stdenvNoCC.hostPlatform.system == "x86_64-linux";
stdenvNoCC.mkDerivation {
  pname = "context-lmtx-sandbox";
  inherit (contextPackage) version;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  # Needed only to exercise the external syntax highlighter in the build.
  # It is intentionally not copied into the portable archive.
  nativeBuildInputs = [ coreutils gnutar xz gawk gnugrep python3 vim ];

  installPhase = ''
    runHook preInstall

    root="$TMPDIR/context-lmtx-ready"
    mkdir -p "$root/tex" "$root/glibc"
    # All files, including texmf.zip, filter and vim, come from the shared
    # Nix derivation. Do not rebuild or download anything here.
    cp -aL ${contextPackage}/tex/. "$root/tex/"
    chmod -R u+w "$root"

    # Keep the desktop package complete, but ship only runtime material in
    # the portable LMTX bundle. LMTX still imports Lua code from mkiv, so
    # never remove mkiv directories or their scripts.
    rm -rf "$root/tex/texmf-context/doc"
    find "$root/tex/texmf-context/tex/context" \
      -type d -name mkii -prune -exec rm -rf -- '{}' +
    find "$root/tex/texmf-context/tex/context" \
      -type f -name '*.mkii' -delete

    bin="$root/tex/texmf-linux-64/bin"
    mv "$bin/luametatex" "$bin/luametatex.bin"
    # The NixOS package has engine aliases. Replace any dereferenced ELF
    # copies with the portable wrapper aliases of the same names.
    rm -f "$bin/mtxrun" "$bin/context"
    cp ${./portable-engine.sh} "$bin/luametatex"
    chmod 755 "$bin/luametatex"
    ln -s luametatex "$bin/mtxrun"
    ln -s luametatex "$bin/context"
    if [ -f "$bin/mtxrun.lmt" ]; then
      test -f "$bin/context.lmt"
    else
      test -f "$bin/mtxrun.lua"
      test -f "$bin/context.lua"
    fi

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

    # Verify provenance against the complete desktop tree, but hash the
    # explicitly pruned portable tree separately. This allows the verifier
    # to detect missing *runtime* assets without requiring bundled manuals.
    export CTX_BUNDLE_ROOT="$root"
    export CTX_SOURCE_TEX='${contextPackage}/tex'
    export CTX_REVISION='${contextPackage.contextRevision or "unknown"}'
    export CTX_VERSION='${contextPackage.version}'
    export CTX_PATCH_LABEL='${contextPackage.patchLabel or ""}'
    bundle_hash=$(${python3}/bin/python3 ${./.}/make-bundle-manifest.py)
    substituteInPlace "$root/context-local.sh" \
      --replace-fail '@BUNDLE_HASH@' "$bundle_hash" \
      --replace-fail '@LOCAL_BUILD_VERSION@' "$CTX_VERSION" \
      --replace-fail '@PATCH_LABEL@' "$CTX_PATCH_LABEL"

    if grep -En '@[A-Za-z][A-Za-z0-9_]*@' "$root/context-local.sh"; then
      echo 'Unsubstituted portable launcher placeholder' >&2
      exit 1
    fi

    # The portable launcher must expose the same local patch version as the
    # native package; check the actual substituted artifact, not the template.
    grep -Fq 'local build: ${contextPackage.version} (${contextPackage.patchLabel or ""})' \
      "$root/context-local.sh" || {
        echo 'Portable ConTeXt version marker missing' >&2
        exit 1
      }

    # Both portable scripts intentionally use #!/usr/bin/env bash, which is
    # absent inside an isolated Nix builder. Rewrite JUST those two shebangs
    # for build-time smoke tests; restore portable ones before archiving.
    # Do not patch the host ConTeXt installPhase or the installed TeX tree.
    patchShebangs --host "$bin/luametatex" "$root/context-local.sh"

    # Fail immediately if obsolete material accidentally re-enters the bundle.
    test ! -e "$root/tex/texmf-context/doc"
    if find "$root/tex/texmf-context/tex/context" \
        \( -type d -name mkii -o -type f -name '*.mkii' \) \
        -print -quit | grep -q .; then
      echo 'Legacy MkII files still present in LMTX sandbox' >&2
      exit 1
    fi

    # Regression gate: loader, fonts, MetaPost, real copy filter and Vim.
    test -f "$root/tex/texmf-context/tex/context/third/filter/t-filter.mkxl"
    test -f "$root/tex/texmf-context/tex/context/third/vim/t-syntax-highlight.mkxl"
    "$bin/luametatex" --version > "$TMPDIR/engine-version.txt"
    "$bin/mtxrun" --version > "$TMPDIR/mtxrun-version.txt"
    export HOME="$TMPDIR/home"
    export TEXMFCACHE="$TMPDIR/cache"
    mkdir -p "$HOME" "$TMPDIR/smoke"
    test_names="smoke"
    if [ -f "$bin/mtxrun.lmt" ]; then
      test_names="$test_names filter vim"
    fi
    bash ${./tests}/run-smoke-tests.sh "$root/context-local.sh" \
      "$TMPDIR/smoke" $test_names

    # A mocked engine tests cache contention, marker reuse and cleanup after
    # an initialization failure. No additional runtime tool is bundled.
    bash ${./tests/check-portable-cache-lock.sh} ${./context-local.sh}

    # Remove Nix-store interpreter paths from the portable launchers. In the
    # final archive, /usr/bin/env resolves bash on the target Linux machine.
    # mtxrun and context remain symlinks to the same portable engine wrapper.
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
