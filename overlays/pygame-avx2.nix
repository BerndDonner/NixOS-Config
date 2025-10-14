# overlays/pygame-avx2.nix
final: prev: {
  python3Packages = prev.python3Packages // {
    pygame-avx2 = prev.python3Packages.pygame.overrideAttrs (old: {
      pname = "pygame-avx2";

      # Add your sed command here (executed right after unpacking and patching)
      postPatch = (old.postPatch or "") + ''
        echo "🛠️  Applying pygame setup.py patch for distutils"
        sed -i "s/distutils.ccompiler.spawn/distutils.spawn.spawn/" setup.py
      '';

      preConfigure = ''
        export PYGAME_DETECT_AVX2=1
        ${old.python.pythonOnBuildForHost.interpreter or prev.python3.pythonOnBuildForHost.interpreter} buildconfig/config.py
      '';

      env = (old.env or {}) // (prev.lib.optionalAttrs prev.stdenv.isx86_64 {
        PYGAME_DETECT_AVX2 = "1";
        NIX_CFLAGS_COMPILE =
          (old.env.NIX_CFLAGS_COMPILE or "") + " -mavx2 -mfma";
      });

      meta = (old.meta or {}) // {
        description = (old.meta.description or "") + " (AVX2-enabled build)";
      };
    });
  };
}

