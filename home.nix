{ config, pkgs, ... }:

{
  # TODO please change the username & home directory to your own
  home.username = "bernd";
  home.homeDirectory = "/home/bernd";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # Packages that should be installed to the user profile.
  home.packages = (with pkgs; [
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them
    firefox
    github-desktop
    arduino-ide
    processing
    stm32cubemx
    kicad
    (blender.override {
        cudaSupport = true;
    })
    obs-studio
    rnote
    inkscape
    rustc
    kmplayer
    gimp
    nerdfonts
    ripgrep
    lazygit
    tree
    gdu
    bottom
    nodejs_20
    xsel
    rclone
    krita
    xinput_calibrator
  ]) ++
  (with pkgs.kdePackages; [
    akonadi
    qtserialport
    pulseaudio-qt
    poppler
    plasma-thunderbolt
    kubrick
    ksvg
    kate
  ]) ++
  ([
    # This is a simple way to install personal packages.
    # The downside is, you cannot depend on these packages.
    # Use overlays when you want to depend on the packages.
    (pkgs.callPackage ./Packages/Context/luametatex.nix {})
  ]);

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    lfs.enable = true;
    userName = "Bernd Donner";
    userEmail = "bernd.donner@sabel.com";
    package = pkgs.gitFull;
    extraConfig = {
      credential = {
        helper = "libsecret";
      };
      init = {
        defaultBranch = "master";
      };
    };
  };

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      vscodevim.vim
      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      ms-vscode.cmake-tools
    ];
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    plugins = with pkgs.vimPlugins; [
      aerial-nvim
      alpha-nvim
      nvim-autopairs
      better-escape-nvim
      cmp_luasnip
      nvim-cmp
      nvim-colorizer-lua
      nvim-comment
      nvim-dap
      dressing-nvim
      gitsigns-nvim
      guess-indent-nvim
      heirline-nvim
      indent-blankline-nvim
      nvim-lspconfig
      lspkind-nvim
      mason-nvim
      # mini-bufremove
      neo-tree-nvim
      neodev-nvim
      none-ls-nvim
      nvim-notify
      nvim-ufo
      # resession
      smart-splits-nvim
      telescope-nvim
      todo-comments-nvim
      toggleterm-nvim
      nvim-treesitter
      nvim-ts-autotag
      nvim-ts-context-commentstring
      # vim-illuminate BUGGY
      nvim-web-devicons
      which-key-nvim
      nvim-window-picker
      LazyVim
    ];
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}

