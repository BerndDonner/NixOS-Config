{ config, pkgs, lib, inputs, ... }:

{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  imports = [
    ./helix.nix
  ];

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
    chromium
    discord
    github-desktop
    arduino-ide
    arduino-cli
    qtcreator
    processing
    stm32cubemx
    kicad
    ngspice
    cudatoolkit
    (blender.override {
        cudaSupport = true;
    })
    obs-studio
    rnote
    inkscape
    rustc
    kmplayer
    qbittorrent
    vlc
    gimp
    lua54Packages.luarocks
    ripgrep
    lazygit
    cargo
    opam
    gcc14
    wezterm
    tree
    gdu
    bottom
    nodejs_20
    wl-clipboard
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
    plasma-browser-integration
    sddm-kcm
    kdeconnect-kde
    kubrick
    ksvg
    kate
    wayland
  ]) ++
  ([
    # This is a simple way to install personal packages.
    # The downside is, you cannot depend on these packages.
    # Use overlays when you want to depend on the packages.
    (pkgs.callPackage ../pkgs/context/luametatex.nix {})
    # (pkgs.callPackage ../Packages/vimPlugin.snacks-nvim/snacks-nvim.nix {})
  ]);

  qt.enable = true;
  fonts.fontconfig.enable = true;

  # java runtime environment for ltex-ls in nvim
  programs.java = {
     enable = true;
     package = pkgs.jre_minimal;
  };

  programs.ssh.enable = true;
  programs.ssh.extraConfig = ''
    Host lenzi
      IdentityFile ~/.ssh/bernd_tracy
      User levi

    Host *
      IdentityFile ~/.ssh/bernds-desktop
  '';

   
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

  programs.vim = {
    enable = true;
#    package = pkgs.vim_configurable;
    plugins = [ pkgs.vimPlugins.vim-sensible ];
    extraConfig = ''
    " Netrw
    syntax on
    set backspace=indent,eol,start

    set noruler                     " I already have my statusbar
    set statusline=
    set statusline+=%#Search#%{(mode()=='n')?'\ \ NORMAL\ ':'''}
    set statusline+=%#Search#%{(mode()=='c')?'\ \ COMMND\ ':'''}
    set statusline+=%#DiffAdd#%{(mode()=='i')?'\ \ INSERT\ ':'''}
    set statusline+=%#DiffDelete#%{(mode()=='r')?'\ \ RPLACE\ ':'''}
    set statusline+=%#DiffDelete#%{(mode()=='R')?'\ \ RPLACE\ ':'''}
    set statusline+=%#DiffChange#%{(mode()=='v')?'\ \ VISUAL\ ':'''}
    set statusline+=%#Cursor#        " colour
    set statusline+=\ %n\            " buffer number
    set statusline+=%#Visual#        " colour
    set statusline+=%{&paste?'\ PASTE\ ':'''}
    set statusline+=%{&spell?'\ SPELL\ ':'''}
    set statusline+=%#CursorIM#      " colour
    set statusline+=%w               " preview flag
    set statusline+=%h               " help flag
    set statusline+=%r               " readonly flag
    set statusline+=%m               " modified [+] flag
    set statusline+=%#CursorLine#    " colour
    set statusline+=\ %t\            " short file name
    set statusline+=%=               " right align
    set statusline+=%#CursorLine#    " colour
    set statusline+=\ %{&filetype}\  " file type (%Y and %y are too ugly)
    set statusline+=%#Visual#        " colour
    set statusline+=\ %3l:%-2c\      " line + column
    set statusline+=%#Cursor#        " colour
    set statusline+=\ %3p%%\         " percentage
    set statusline+=%#CursorLine#    " colour

    set laststatus=2

    let g:netrw_banner = 0
    let g:netrw_liststlye = 3
    let g:netrw_browse_split = 4
    let g:netrw_winsize = 20
    let g:netrw_altv = 1

    au FileType netrw setl bufhidden=wipe

    " function! OpenToRight()
    "   :normal v 
    "   let g:path=expand('%:p')
    "   :q!
    "   execute 'belowright vnew' g:path
    "   :wincmd l
    " endfunction
    " 
    " function! OpenToLeft()
    "   :normal v 
    "   let g:path=expand('%:p')
    "   :q!
    "   :wincmd l
    "   execute 'aboveleft vnew' g:path
    " "  :wincmd l
    " endfunction
    " 
    " 
    " 
    " function! OpenBelow()
    "   :normal v
    "   let g:path=expand('%:p')
    "   :q!
    "   execute 'belowright new' g:path
    "   :wincmd l
    " endfunction
    " 
    " function! NetrwMappings()
    "   noremap <buffer> <C-l> <C-w>l
    "   noremap <silent> <C-f> :call ToggleNetrw()<CR>
    "   noremap <buffer> V :call OpenToRight()<cr>
    " "  noremap <buffer> v :call OpenToLeft()<cr>
    "   noremap <buffer> H :call OpenBelow()<cr>
    " endfunction
    " 
    " augroup netrw_mappings
    "   autocmd!
    "   autocmd filetype netrw call NetrwMappings()
    " augroup END  
    "   
    " let g:NetrwIsOpen=0
    " 
    " "Allow for netrw to be toggled
    " function! ToggleNetrw()
    "   if g:NetrwIsOpen
    "     let i = bufnr("$")
    "   while (i >= 1)
    "     if (getbufvar(i, "&filetype") == "netrw")
    "       silent exe "bwipeout " . i
    "     endif
    "     let i-=1
    "   endwhile
    "   let g:NetrwIsOpen=0
    "   else
    "     let g:NetrwIsOpen=1
    "   silent Lexplore
    "   endif
    " endfunction  
    " 
    " " Close Netrw if it's the only buffer open
    " autocmd WinEnter * if winnr('$') == 1 && getbufvar(winbufnr(winnr()), "&filetype") == "netrw" || &buftype == 'quickfix' |q|endif
    " 
    " " Make netrw act like a project Draw
    " augroup ProjectDrawer
    "   autocmd!
    "   autocmd VimEnter * :call ToggleNetrw()
    " augroup END  
    " 
    set number
    set relativenumber
    set mouse=a
    set tabstop=2
    set autoindent
    set encoding=utf-8
    setlocal textwidth=120
    setlocal colorcolumn=+1
    set whichwrap+=<,>,h,l


    let s:wrapenabled = 0

    if has("gui_running")
      if has("gui_gtk2")
        set guifont=Inconsolata\ 12
      elseif has("gui_macvim")
        set guifont=Menlo\ Regular:h14
      elseif has("gui_win32")
        set guifont=Consolas:h11:cANSI
      endif
    endif
        
    function! ToggleWrap()
      set wrap nolist
      if s:wrapenabled
        set nolinebreak
        unmap j
        unmap k
        unmap 0
        unmap ^
        unmap $
        let s:wrapenabled = 0
      else
        set linebreak
        nnoremap j gj
        nnoremap k gk
        nnoremap 0 g0
        nnoremap ^ g^
        nnoremap $ g$
        vnoremap j gj
        vnoremap k gk
        vnoremap 0 g0
        vnoremap ^ g^
        vnoremap $ g$
        let s:wrapenabled = 1
      endif
    endfunction
    map <leader>w :call ToggleWrap()<CR
    '';
  };

  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    # viAlias = true;
    # vimAlias = true;
    vimdiffAlias = true;


    # these packages will only be available to neovim
    # see ./lua/myconfig/formatters.lua and ./lua/myconfig/lspservers.lua
    # for making them known to neovim
    extraPackages = with pkgs.unstable; [
      tree-sitter
      gcc # treesitter needs gcc

      # Lua LSP
      lua5_1
      lua-language-server # LSP
      luarocks
      stylua # formatter

      # Nix
      alejandra #formatter
      nixd # LSP

      # Python
      nodejs # required by pyright and prettier
      pyright
      ruff

      nodePackages.prettier
    ];

    # the only plugin that I need is lazy, because lazy will load the rest of the plugins
    # that is made reproducable by committing the lazy-lock.json file
    plugins = [pkgs.vimPlugins.lazy-nvim];
  };

  # this is a hack to enable mason on neovim

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.activation."nix-registry" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    flake_path=${inputs.self.outPath}
    echo "🔗 Ensuring registry entry 'nixos-config' → $flake_path"
    nix registry list | grep -q "nixos-config" \
      || nix registry add nixos-config "path:$flake_path"
  '';
  

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}

