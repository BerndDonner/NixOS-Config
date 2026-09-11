{ config, inputs, pkgs, lib, ... }:
let
  cfg = config.donner.helix;
  system = pkgs.stdenv.hostPlatform.system;

  # Helix with Steel support.
  #
  # The cursor-history lock helper is injected as an additional Cargo workspace
  # member. This makes it inherit Helix's exact steel-core dependency (source,
  # revision and features), share Helix's Cargo.lock/vendor set, and use the
  # same Rust toolchain in the same build. No separate Cargo.toml/Cargo.lock is
  # maintained for the helper.
  helixCargoLock =
    fromTOML (builtins.readFile "${inputs.helix}/Cargo.lock");

  abiStablePackage =
    lib.findFirst
      (package: package.name == "abi_stable")
      null
      helixCargoLock.package;

  abiStableVersion =
    if abiStablePackage == null then
      throw "Helix Cargo.lock does not contain abi_stable"
    else
      abiStablePackage.version;

  helix = inputs.helix.packages.${system}.default.overrideAttrs (old: {
    cargoBuildFeatures =
      lib.unique ((old.cargoBuildFeatures or [ ]) ++ [ "steel" "git" ]);

    # Build Helix and the native cursor-history helper in the same Cargo
    # invocation. Cargo's workspace shares one lock file and one target tree.
    cargoBuildFlags =
      (old.cargoBuildFlags or [ ])
      ++ [
        "--package"
        "helix-term"
        "--package"
        "cursor-history-lock"
      ];

    postPatch = (old.postPatch or "") + ''
      mkdir -p cursor-history-lock/src
      cp ${./helix/cursor-history-lock/src/lib.rs} \
        cursor-history-lock/src/lib.rs

      cat > cursor-history-lock/Cargo.toml <<'CARGO_EOF'
      [package]
      name = "cursor-history-lock"
      version = "0.1.0"
      edition.workspace = true
      rust-version.workspace = true

      [lib]
      name = "cursor_history_lock"
      crate-type = ["cdylib"]

      [dependencies]
      steel-core = { workspace = true }
      abi_stable = "=${abiStableVersion}"
      CARGO_EOF

      # Make the helper a real Helix workspace member. Its steel-core
      # dependency therefore inherits Helix's workspace dependency verbatim.
      sed -i '/^members = \[/a\  "cursor-history-lock",' Cargo.toml
    '';

    preBuild = (old.preBuild or "") + ''
      cargo xtask code-gen
    '';

    postInstall = (old.postInstall or "") + ''
      dylib="$(find target -type f -name 'libcursor_history_lock.so' -print -quit)"
      if [ -z "$dylib" ]; then
        echo >&2 "cursor-history-lock: built dylib not found"
        exit 1
      fi

      install -Dm755 "$dylib" \
        "$out/lib/steel/native/libcursor_history_lock.so"
    '';
  });

  # External Steel runtime used for the Steel language server and, on the
  # desktop hosts, Forge. This is NOT a build dependency of Helix or the native
  # helper: Helix embeds its own steel-core, and the helper inherits that exact
  # Cargo workspace dependency during the Helix build above.
  #
  # cloud only needs the Steel language server. tracy/kitty keep Forge too.
  steelRuntime = inputs.steel.packages.${system}.default.override {
    includeLSP = true;
    includeForge = cfg.steelForge;
  };

  # Explicit Helix runtime tooling for workstation hosts. These packages are
  # not needed merely to BUILD Helix/Steel. In particular clang-tools brings
  # LLVM 18 and nixd currently brings LLVM 21 into the runtime closure.
  developmentPackages = with pkgs.unstable; [
    llvmPackages_18.clang-tools # C/C++
    rust-analyzer               # Rust
    gopls                       # Golang
    bash-language-server       # Bash
    dockerfile-language-server # Dockerfile
    vscode-langservers-extracted # HTML/CSS/JSON
    texlab                     # LaTeX

    # Markdown
    markdown-oxide
    marksman

    # TS/JS
    typescript-language-server
    prettier

    # Nix
    nixfmt
    nixd

    cmake-language-server
    taplo
    python312Packages.python-lsp-server
    lua-language-server
  ];

  # Use the same package instances in generated languages.toml and in
  # extraPackages. This avoids accidentally pulling stable + unstable copies.
  nixdPackage = pkgs.unstable.nixd;
  nixfmtPackage = pkgs.unstable.nixfmt;
  prettierPackage = pkgs.unstable.prettier;

  cursorHistoryDir = "${config.xdg.stateHome}/helix";

  # Keep machine-specific state paths out of the plugin source. Home Manager
  # generates this tiny module; cursor-history.scm itself stays plain Steel.
  cursorHistoryConfigScheme = ''
    (provide cursor-history-state-dir)
    (define cursor-history-state-dir ${builtins.toJSON cursorHistoryDir})
  '';
in
{
  options.donner.helix = {
    developmentTools = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the workstation Helix runtime toolchain (LSP servers,
        formatters and related tools). Keep this disabled on small servers.
      '';
    };

    steelForge = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Build/install Forge as part of the external Steel runtime. The embedded
        Steel engine inside Helix does not depend on this.
      '';
    };
  };

  config = {
    home.packages = [
      steelRuntime
    ];

    programs.helix = {
      enable = true;
      package = helix;

      settings = {
        theme = "gruvbox_dark_hard";

        editor.auto-format = true;
        editor.auto-save = true;
        editor.bufferline = "multiple";
        editor.color-modes = true;
        editor.cursorline = true;
        editor.line-number = "relative";
        editor.mouse = true;
        editor.rulers = [ 80 ];
        editor.scrolloff = 10;
        editor.whitespace.render = "all";
        editor.rainbow-brackets = true;

        editor.indent-guides = {
          render = true;
          character = "|";
        };

        editor.cursor-shape = {
          normal = "block";
          insert = "block";
          select = "block";
        };

        editor.lsp = {
          enable = true;
          display-messages = true;
          display-inlay-hints = true;
        };

        editor.statusline = {
          left = [ "mode" "spinner" "version-control" ];
          center = [ "file-name" "file-modification-indicator" ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
            "file-line-ending"
            "file-type"
          ];
          separator = "│";
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
        };
      };

      languages.language-server = {
        steel = {
          command = "steel-language-server";
        };
      } // lib.optionalAttrs cfg.developmentTools {
        nixd = {
          command = lib.getExe nixdPackage;
        };
      };

      languages.language = [
        {
          name = "scheme";
          language-servers = [ "steel" ];
        }
      ] ++ lib.optionals cfg.developmentTools [
        {
          name = "typescript";
          language-servers = [ "typescript-language-server" ];
          formatter.command = "prettier";
          formatter.binary = lib.getExe prettierPackage;
          formatter.args = [ "--parser" "typescript" ];
        }

        {
          name = "nix";
          language-servers = [ "nixd" ];
          formatter.command = "nixfmt";
          formatter.binary = lib.getExe nixfmtPackage;
        }
      ];

      # Runtime tools visible to Helix. Nix already keeps build-only
      # dependencies out of the target closure unless an installed binary
      # actually references them at runtime.
      extraPackages = lib.optionals cfg.developmentTools developmentPackages;
    };

    # Steel cog, generated machine-specific config, and native lock helper.
    xdg.configFile."helix/cogs/cursor-history.scm".source =
      ./helix/cursor-history.scm;

    xdg.configFile."helix/cogs/cursor-history-config.scm".text =
      cursorHistoryConfigScheme;

    xdg.dataFile."steel/native/libcursor_history_lock.so".source =
      "${helix}/lib/steel/native/libcursor_history_lock.so";

    xdg.configFile."helix/init.scm".text = ''
      (require (only-in "helix/ext.scm" evalp eval-buffer))
      (require "cogs/cursor-history.scm")
    '';
  };
}
