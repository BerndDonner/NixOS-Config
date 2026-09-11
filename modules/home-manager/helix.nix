{ config, inputs, pkgs, lib, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # Helix with Steel support.
  helix = inputs.helix.packages.${system}.default.overrideAttrs (old: {
    cargoBuildFeatures =
      lib.unique ((old.cargoBuildFeatures or [ ]) ++ [ "steel" "git" ]);

    preBuild = (old.preBuild or "") + ''
      cargo xtask code-gen
    '';
  });

  # Steel toolchain: steel, forge, steel-language-server, cargo-steel-lib.
  steel = inputs.steel.packages.${system}.default;

  cursorHistoryDir = "${config.xdg.stateHome}/helix";

  # Native helper for an OS-level advisory file lock. It must be built against
  # the same Steel ABI as Helix. Cargo.lock pins the exact Steel commit used by
  # the current Helix input; the checks below fail the build after a Helix
  # update instead of installing an ABI-incompatible dylib that could crash.
  cursorHistoryLock = pkgs.unstable.rustPlatform.buildRustPackage {
    pname = "cursor-history-lock";
    version = "0.1.0";

    src = ./helix/cursor-history-lock;

    # The lock file contains git dependencies. For this personal configuration
    # importCargoLock can fetch the pinned git revision directly. This uses IFD.
    cargoDeps = pkgs.unstable.rustPlatform.importCargoLock {
      lockFile = ./helix/cursor-history-lock/Cargo.lock;
      allowBuiltinFetchGit = true;
    };
    cargoHash = null;

    doCheck = false;

    preBuild = ''
      package_field() {
        local lock_file="$1"
        local package="$2"
        local field="$3"

        awk -v package="$package" -v field="$field" '
          $0 == "name = \"" package "\"" { in_package = 1; next }
          in_package && $0 ~ ("^" field " = ") {
            sub("^" field " = \"", "")
            sub("\"$", "")
            print
            exit
          }
          in_package && /^\[\[package\]\]/ { exit }
        ' "$lock_file"
      }

      plugin_steel_source="$(package_field Cargo.lock steel-core source)"
      helix_steel_source="$(package_field ${inputs.helix}/Cargo.lock steel-core source)"

      plugin_steel_rev="''${plugin_steel_source##*#}"
      helix_steel_rev="''${helix_steel_source##*#}"

      if [ "$plugin_steel_rev" != "$helix_steel_rev" ]; then
        echo >&2 "cursor-history-lock: Steel revision no longer matches Helix."
        echo >&2 "plugin: $plugin_steel_rev"
        echo >&2 "helix:  $helix_steel_rev"
        echo >&2 "Regenerate cursor-history-lock/Cargo.lock against Helix's Steel revision."
        exit 1
      fi

      plugin_abi_version="$(package_field Cargo.lock abi_stable version)"
      helix_abi_version="$(package_field ${inputs.helix}/Cargo.lock abi_stable version)"

      if [ "$plugin_abi_version" != "$helix_abi_version" ]; then
        echo >&2 "cursor-history-lock: abi_stable version no longer matches Helix."
        echo >&2 "plugin: $plugin_abi_version"
        echo >&2 "helix:  $helix_abi_version"
        exit 1
      fi

      helix_steel_decl="$(grep '^steel-core = ' ${inputs.helix}/Cargo.toml)"
      helix_features="$({
        printf '%s\n' "$helix_steel_decl" \
          | sed -n 's/.*features = \[\([^]]*\)\].*/\1/p' \
          | tr ',' '\n' \
          | tr -d ' \"' \
          | sed '/^$/d' \
          | sort \
          | paste -sd, -
      })"
      expected_features="$(printf '%s\n' anyhow biased dylibs imbl sync | sort | paste -sd, -)"

      if [ "$helix_features" != "$expected_features" ]; then
        echo >&2 "cursor-history-lock: Steel feature set no longer matches Helix."
        echo >&2 "expected: $expected_features"
        echo >&2 "helix:    $helix_features"
        exit 1
      fi
    '';

    installPhase = ''
      runHook preInstall

      dylib="$(find target -type f -name 'libcursor_history_lock.so' -print -quit)"
      if [ -z "$dylib" ]; then
        echo >&2 "cursor-history-lock: built dylib not found"
        exit 1
      fi

      install -Dm755 "$dylib" "$out/lib/libcursor_history_lock.so"

      runHook postInstall
    '';
  };
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
    "${cursorHistoryLock}/lib/libcursor_history_lock.so";

  xdg.configFile."helix/init.scm".text = ''
    (require (only-in "helix/ext.scm" evalp eval-buffer))
    (require "cogs/cursor-history.scm")

    (cursor-history-install!
      "${cursorHistoryDir}"
      "${cursorHistoryDir}/cursor-history.scm")
  '';
}
