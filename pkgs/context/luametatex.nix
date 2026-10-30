{ lib
, stdenv
, fetchzip
, cmake
, coreutils
, gnumake
, ninja
, runtimeShell
, vim
, patch
, util-linux
, contextSource
, contextRevision
, moduleFilter
, enginePatches ? [ ]
, localVersion ? null
, patchLabel ? ""
}:

stdenv.mkDerivation rec {
  # Export the pinned filter/Vim source to shell build phases as $moduleFilter.
  inherit moduleFilter;
  pname = "luametatex";

  # Source revisions are pinned by the root flake inputs/lock.
  # Display a distinct Nix version for local patches without changing
  # ConTeXt's internal contextversion, which controls format handling.
  version = if localVersion == null
    then "unstable-${builtins.substring 0 12 contextRevision}"
    else localVersion;
  src = contextSource;

  # Ordered engine patches are configurable for any pinned source revision.
  # The root overlay enables our Math/Glue patch for the productive default.
  patches = enginePatches;
  # Fail on changed patch context rather than silently accepting fuzzy hunks
  # when moving experiments to another upstream revision.
  patchFlags = [ "-p1" "--fuzz=0" ];

  # Filter and Vim are supplied through the pinned root flake input.
  # ca120d8 already uses file.canbewritten; no local module patch needed.

  # ConTeXt's Git repository omits this bootstrap/font TeX tree.
  # It is intentionally retained with the original fixed-output hash.
  texmf = fetchzip {
    url    = "http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip";
    sha256 = "sha256-S3kCPJqB+0+CD7S7ai6yalOQihzhHy6XS1krFdWhdVc=";
  };

  # Real filter/Vim tests run during the build; these tools are not
  # runtime dependencies of the installed NixOS ConTeXt package.
  nativeBuildInputs = [ cmake gnumake ninja coreutils vim patch ];

  # Use the upstream default LuaMetaTeX build (without LuaSocket).
  # ConTeXt 2026 launches through mtxrun.lmt/context.lmt, not mtxrun.lua.
  configurePhase = ''
    # IMPORTANT: $src is the unmodified store source! Use the unpacked,
    # patchPhase-modified source tree instead.
    cmake -B build -S "$PWD/source/luametatex" -DCMAKE_BUILD_TYPE=Release
  '';

  buildPhase = ''
    cmake --build build
  '';

  installPhase = ''
    runHook preInstall

    echo "Installing LuaMetaTeX / ConTeXt tree"
    mkdir -p "$out/bin" "$out/tex/texmf-linux-64/bin" "$out/tex/texmf-context"

    # Select the runner layout from the unpacked source, not from a fixed
    # commit hash. Works with both the 2024 .lua and modern .lmt sources.
    cp build/luametatex "$out/tex/texmf-linux-64/bin/"
    runner_dir="$PWD/scripts/context/lua"
    if [ -f "$runner_dir/mtxrun.lmt" ] && [ -f "$runner_dir/context.lmt" ]; then
      suffix=lmt
    elif [ -f "$runner_dir/mtxrun.lua" ] && [ -f "$runner_dir/context.lua" ]; then
      suffix=lua
    else
      echo 'Missing or inconsistent ConTeXt runner scripts' >&2
      exit 1
    fi
    for script in mtxrun context; do
      cp "$runner_dir/$script.$suffix" \
         "$out/tex/texmf-linux-64/bin/"
    done
    ln -s luametatex "$out/tex/texmf-linux-64/bin/mtxrun"
    ln -s luametatex "$out/tex/texmf-linux-64/bin/context"

    # Assemble standalone shell bodies; shared environment is embedded so
    # installed launchers need no additional runtime shell library.
    for name in context-init-cache context mtxrun; do
      cp ${./native-environment.sh} "$out/bin/$name"
      chmod u+w "$out/bin/$name"
    done
    cat ${./native-init-cache.sh} >> "$out/bin/context-init-cache"
    cat ${./native-context.sh} >> "$out/bin/context"
    printf '\nexec "%s/tex/texmf-linux-64/bin/mtxrun" "$@"\n' "$out" >> "$out/bin/mtxrun"
    for name in context-init-cache context mtxrun; do
      substituteInPlace "$out/bin/$name" \
        --replace-fail '@runtimeShell@' '${runtimeShell}'
    done
    substituteInPlace "$out/bin/context-init-cache" \
      --replace-fail '@out@' "$out" \
      --replace-fail '@utilLinux@' '${util-linux}' \
      --replace-fail '@packageId@' "$(basename "$out")"
    substituteInPlace "$out/bin/context" \
      --replace-fail '@out@' "$out" \
      --replace-fail '@packageId@' "$(basename "$out")" \
      --replace-fail '@localVersion@' ${lib.escapeShellArg (lib.escapeShellArg (if localVersion == null then "" else version))} \
      --replace-fail '@patchLabel@' ${lib.escapeShellArg (lib.escapeShellArg patchLabel)}

    cat > "$out/bin/luametatex" <<EOF
#!${runtimeShell}
set -eu
exec "$out/tex/texmf-linux-64/bin/luametatex" "\$@"
EOF
    if grep -En '@[A-Za-z][A-Za-z0-9_]*@' "$out/bin/"*; then
      echo 'Unsubstituted native launcher placeholder' >&2
      exit 1
    fi
    chmod +x "$out/bin/"*

    # Machine-readable provenance, independent of the store directory name.
    mkdir -p "$out/share/context"
    cp ${builtins.toFile "context-build-info.json" (builtins.toJSON {
      schema_version = 1;
      context_revision = contextRevision;
      package_version = version;
      patch_label = patchLabel;
    })} "$out/share/context/build-info.json"

    # Copy TeX trees
    echo "Copying TeX trees"
    cp -r "$texmf/texmf" "$out/tex/"
    for d in colors context doc fonts metapost scripts tex web2c; do
      cp -r "$PWD/$d" "$out/tex/texmf-context/"
    done

    # Only these parents must be writable to add third-party modules;
    # do not recursively chmod the entire TeX tree.
    chmod u+w \
      "$out/tex/texmf-context/tex/context" \
      "$out/tex/texmf-context/doc/context"

    # Third-party modules (filter + vim)
    mkdir -p \
      "$out/tex/texmf-context/tex/context/third/filter" \
      "$out/tex/texmf-context/doc/context/third/filter" \
      "$out/tex/texmf-context/tex/context/third/vim" \
      "$out/tex/texmf-context/doc/context/third/vim"

    cp "$moduleFilter"/README.md \
       "$out/tex/texmf-context/doc/context/third/filter/"
    cp "$moduleFilter"/t-{filter*,module*} \
       "$out/tex/texmf-context/tex/context/third/filter/"
    cp "$moduleFilter"/vim-README.md \
       "$out/tex/texmf-context/doc/context/third/vim/"
    cp "$moduleFilter"/{t-syntax-*,2context.vim,t-vim.tex,vimtyping-default.css} \
       "$out/tex/texmf-context/tex/context/third/vim/"

    # No cache generation in the Nix store!
    # Per-user cache and fonts DB are initialized on first use.

    runHook postInstall
  '';

  # Regression test: catch a missing .lmt launcher, an unresolvable
  # mtx-context.lua or an unusable TeX tree already in the local package.
  # Keep all caches, including format files, outside the read-only Nix store.
  postInstall = ''
    # Filter/Vim compatibility is checked by the real smoke documents below.
    # No local t-filter.mkxl patch: ca120d8 contains the upstream fix.
    export HOME="$TMPDIR/context-smoke-home"
    export TEXMFCACHE="$TMPDIR/context-smoke-cache"
    mkdir -p "$HOME" "$TMPDIR/context-smoke-doc"
    "$out/bin/mtxrun" --generate > "$TMPDIR/ctx-generate.log" 2>&1 || {
      cat "$TMPDIR/ctx-generate.log" >&2; exit 1;
    }
    located=$("$out/bin/mtxrun" --locate --first mtx-context.lua) || {
      echo "ConTeXt resolver could not locate mtx-context.lua" >&2; exit 1;
    }
    test -f "$located" || {
      echo "ConTeXt resolver returned a missing script: $located" >&2; exit 1;
    }
    "$out/bin/context" --make > "$TMPDIR/ctx-make.log" 2>&1 || {
      cat "$TMPDIR/ctx-make.log" >&2; exit 1;
    }
    test_names="smoke"
    if [ -f "$out/tex/texmf-linux-64/bin/mtxrun.lmt" ]; then
      test_names="$test_names filter vim"
    fi
    bash ${./tests}/run-smoke-tests.sh "$out/bin/context" \
      "$TMPDIR/context-smoke-doc" $test_names
    ${lib.optionalString (localVersion != null) ''
      "$out/bin/context" --version > "$TMPDIR/ctx-version.log" 2>&1
      grep -Fq 'local build: ${version} (${patchLabel})' "$TMPDIR/ctx-version.log" || {
        cat "$TMPDIR/ctx-version.log" >&2
        echo 'Local ConTeXt version marker missing' >&2
        exit 1
      }
    ''}
    # Exercise two simultaneous first starts and forced reinitialization.
    bash ${./tests/check-native-cache-lock.sh} "$out/bin/context"
  '';

  meta = with lib; {
    description = "LuaMetaTeX engine (ConTeXt LMTX) – integrates TeX and MetaPost with Lua";
    homepage    = "https://wiki.contextgarden.net";
    license     = licenses.gpl2;
    platforms   = [ "x86_64-linux" ];
    maintainers = [ ];
  };

  passthru = {
    # Evaluated metadata; used by the independent sandbox archive derivation.
    inherit contextRevision patchLabel;
    tests.smoke = ''
      $out/bin/luametatex --version
    '';
  };
}
