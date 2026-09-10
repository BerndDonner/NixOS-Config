{ inputs, pkgs, lib, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

    # Helix with Steel support.
  helix = inputs.helix.packages.${system}.default;

  # Steel toolchain: steel, forge, steel-language-server, cargo-steel-lib.
  steel = inputs.steel.packages.${system}.default;
in
{
  home.packages = [
    steel
  ];

  programs.helix = {
    enable = true;
    # package = (builtins.getFlake "github:helix-editor/helix").packages.${pkgs.system}.default;
    package = helix;
    # package = pkgs.unstable.helix;
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
    ];

    # LSPs and formatters installed globally for convenience
    extraPackages = with pkgs.unstable; [
      llvmPackages_18.clang-tools # C/C++
      rust-analyzer # Rust
      gopls # Golang
      bash-language-server # Bash
      dockerfile-language-server # Dockerfile
      vscode-langservers-extracted # HTML/CSS/JSON
      texlab # LaTEX

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
}
