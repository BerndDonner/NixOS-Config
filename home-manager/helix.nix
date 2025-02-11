{ pkgs, lib, ... }:
let
  # Skips the input but impurifies the build (use --impure to rebuild)
  helix = (builtins.getFlake "github:helix-editor/helix/355e38162624fdd411bd19b1ca19e5e2733159ba").packages.${pkgs.system}.default;

  # helix = inputs.helix.packages.${pkgs.system}.default;
in
{
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
      command = "${lib.getExe pkgs.nixd}";
    };

    languages.language = [
      {
        name = "typescript";
        language-servers = [ "typescript-language-server" ];
        formatter.command = "prettier";
        formatter.args = [ "--parser" "typescript" ];
        formatter.binary = "${lib.getExe pkgs.nodePackages.prettier}";
      }
      {
        name = "nix";
        language-servers = [ "nixd" ];
        formatter.binary = "${lib.getExe pkgs.nixfmt-classic}";
        formatter.command = "nixfmt";
      }
    ];

    # LSPs and formatters installed globally for convenience
    extraPackages = with pkgs.unstable; [
      llvmPackages_18.clang-tools # C/C++
      rust-analyzer # Rust
      gopls # Golang
      nodePackages.bash-language-server # Bash
      dockerfile-language-server-nodejs # Dockerfile
      vscode-langservers-extracted # HTML/CSS/JSON
      texlab # LaTEX

      # Markdown
      markdown-oxide
      marksman

      # TS/JS
      nodePackages.typescript-language-server
      nodePackages.prettier

      # Nix
      nixfmt-classic
      nixd

      cmake-language-server
      taplo
      python312Packages.python-lsp-server
      lua-language-server

    ];

  };
}
