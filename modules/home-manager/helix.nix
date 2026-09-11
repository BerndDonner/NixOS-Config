{ config, inputs, pkgs, lib, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # Helix with Steel support.
  #
  # The cursor-history lock helper is injected as an additional Cargo workspace
  # member. This makes it inherit Helix's exact steel-core dependency (source,
  # revision and features), share Helix's Cargo.lock/vendor set, and use the
  # same Rust toolchain in the same build. No separate Cargo.toml/Cargo.lock is
  # maintained for the helper.
  helixCargoLock =
    builtins.fromTOML (builtins.readFile "${inputs.helix}/Cargo.lock");

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

      cat > cursor-history-lock/Cargo.toml <<'EOF'
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
      EOF

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

  # Steel toolchain for Forge and the Steel language server. This is not used
  # to build the native helper; the helper intentionally follows Helix's own
  # steel-core Cargo dependency instead.
  steel = inputs.steel.packages.${system}.default;

  cursorHistoryDir = "${config.xdg.stateHome}/helix";
in
{
  home.packages = [
    steel
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

    languages.language-server.nixd = {
      command = lib.getExe pkgs.nixd;
    };

    languages.language-server.steel = {
      command = "steel-language-server";
    };

    languages.language = [
      {
        name = "typescript";
        language-servers = [ "typescript-language-server" ];
        formatter.command = "prettier";
        formatter.args = [ "--parser" "typescript" ];
        formatter.binary = lib.getExe pkgs.prettier;
      }

      {
        name = "nix";
        language-servers = [ "nixd" ];
        formatter.binary = lib.getExe pkgs.nixfmt;
        formatter.command = "nixfmt";
      }

      {
        name = "scheme";
        language-servers = [ "steel" ];
      }
    ];

    # LSPs and formatters installed globally for convenience.
    extraPackages = with pkgs.unstable; [
      llvmPackages_18.clang-tools # C/C++
      rust-analyzer              # Rust
      gopls                      # Golang
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
  };

  # Steel cog and its native lock helper.
  xdg.configFile."helix/cogs/cursor-history.scm".source =
    ./helix/cursor-history.scm;

  xdg.dataFile."steel/native/libcursor_history_lock.so".source =
    "${helix}/lib/steel/native/libcursor_history_lock.so";

  xdg.configFile."helix/init.scm".text = ''
    (require (only-in "helix/ext.scm" evalp eval-buffer))
    (require "cogs/cursor-history.scm")

    (cursor-history-install!
      "${cursorHistoryDir}"
      "${cursorHistoryDir}/cursor-history.scm")
  '';
}
