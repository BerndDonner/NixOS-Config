{ config, pkgs, lib, inputs, ... }:

{
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
    google-chrome
    discord
    magic-wormhole
    github-desktop
    qtcreator
    processing
    stm32cubemx
    kicad
    ngspice
    obs-studio
    xournalpp
    inkscape
    rustc
    haruna
    qbittorrent
    vlc
    gimp
    lua54Packages.luarocks
    ripgrep
    lazygit
    cargo
    opam
    gcc14
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
    kwallet
    kwalletmanager
    wayland
  ]) ++
  ([
    # This is a simple way to install personal packages.
    # The downside is, you cannot depend on these packages.
    # Use overlays when you want to depend on the packages.
    (pkgs.callPackage ../pkgs/context/luametatex.nix {})
  ]);

  qt.enable = true;
  fonts.fontconfig.enable = true;

  # java runtime environment for ltex-ls in nvim
  programs.java = {
     enable = true;
     package = pkgs.jre_minimal;
  };

programs.ssh = {
  enable = true;
  enableDefaultConfig = false;

  # IP-Fallback: wenn du per IP connectest, nimm immer den Wegwerf-Key
  extraConfig = ''
    Match host *, exec "echo %h | grep -Eq '^([0-9]{1,3}\\.){3}[0-9]{1,3}$'"
      User ubuntu
      IdentityFile ~/.ssh/id_tabby_bootstrap
      IdentitiesOnly yes
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
      LogLevel ERROR
  '';

  matchBlocks = {
    # Dein stabiler Name zeigt auf ephemere IP -> genauso behandeln wie IP
    "ai-donner-lab" = {
      host = "ai.donner-lab.org";
      user = "ubuntu";
      identityFile = "~/.ssh/id_tabby_bootstrap";
      identitiesOnly = true;
      extraOptions = {
        StrictHostKeyChecking = "no";
        UserKnownHostsFile = "/dev/null";
        LogLevel = "ERROR";
      };
    };

    # GitHub (Deploy Key)
    "github-tabby-bootstrap" = {
      host = "github.com";
      user = "git";
      identityFile = "~/.ssh/id_tabby_bootstrap";
      identitiesOnly = true;
      extraOptions = { StrictHostKeyChecking = "accept-new"; };
    };

    # Forgejo Beispiel (falls du willst, hier dein Host)
    "forgejo-meisterk" = {
      host = "forgejo.meisterk.de";
      user = "git";
      identityFile = "~/.ssh/bernds-desktop";
      identitiesOnly = true;
      extraOptions = { StrictHostKeyChecking = "accept-new"; };
    };

    "lenzi" = {
      user = "levi";
      identityFile = "~/.ssh/bernd_tracy";
      identitiesOnly = true;
    };

    "*" = {
      identityFile = "~/.ssh/bernds-desktop";
      identitiesOnly = true;
    };
  };
};
   
  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    settings = {
      user.name  = "Bernd Donner";
      user.email = "bernd.donner@sabel.com";

      credential.helper = "kwallet";
      init.defaultBranch = "master";

      # Workflow-Defaults
      pull.rebase = true;
      rebase.autoStash = true;
      fetch.prune = true;
      rerere.enabled = true;

      # Wenn irgendwo doch "pull" ohne rebase passiert: nur FF, keine Merge-Commits
      merge.ff = "only";

      alias = {
        # Überblick
        st = "status -sb";
        lg = "log --oneline --graph --decorate --all";
        br = "branch -vv";

        # Publish (setzt upstream, falls noch nicht gesetzt)
        pub = ''!f(){ b=$(git rev-parse --abbrev-ref HEAD); git push -u origin "$b"; }; f'';

        # up --force : fetch + rebase auf upstream (auch mit lokalen Commits ok)
        # up: fetch + rebase auf upstream, aber bricht ab wenn unpushed Commits existieren (Multi-PC-sicher)
        up = ''
          !f(){ \
            set -e; \
            force=0; \
            if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then force=1; shift; fi; \
            u=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || { \
              echo "ERROR: No upstream configured. Run: git pub"; exit 1; }; \
            ahead=$(git rev-list --count @{u}..HEAD); \
            if [ "$ahead" -gt 0 ] && [ "$force" -eq 0 ]; then \
              echo "ERROR: You have $ahead local commit(s) that are NOT pushed."; \
              echo "       Run: git pub   or (explicitly): git up --force"; \
              exit 1; \
            fi; \
            if [ "$ahead" -gt 0 ] && [ "$force" -eq 1 ]; then \
              b=$(git rev-parse --abbrev-ref HEAD); \
              echo "⚠️  WARNING: git up --force"; \
              echo "   Branch:   $b"; \
              echo "   Upstream: $u"; \
              echo "   Status:   ahead by $ahead commit(s) (not pushed)"; \
              echo "   Action:   fetch + rebase --autostash onto upstream"; \
              echo "   Note:     If you push afterwards, you may need --force-with-lease."; \
              echo "             Conflicts are normal here. To abort: git abort-op"; \
              echo ""; \
            fi; \
            git fetch --prune; \
            git rebase --autostash @{u}; \
          }; f
        '';


        # Konflikt-Helfer mit verständlichen Namen (rebase-sicher)
        # Conflict helpers:
        # - git current <file>  : keep the version currently checked out in your working tree
        # - git incoming <file> : take the version from the other side (the one being merged/rebased in)
        # After choosing: git add <file> and continue (git rebase --continue / git commit)
        current = ''
          !f(){ \
            if test -d "$(git rev-parse --git-path rebase-apply)" -o -d "$(git rev-parse --git-path rebase-merge)"; then \
              git checkout --theirs -- "$@"; \
            else \
              git checkout --ours -- "$@"; \
            fi; \
          }; f
        '';
        incoming = ''
          !f(){ \
            if test -d "$(git rev-parse --git-path rebase-apply)" -o -d "$(git rev-parse --git-path rebase-merge)"; then \
              git checkout --ours -- "$@"; \
            else \
              git checkout --theirs -- "$@"; \
            fi; \
          }; f
        '';

        # Lebensretter
        undo    = "reset --soft HEAD~1";
        discard = "reset --hard";

        # Feature-Branch hart auf Remote zurücksetzen (Schutz für master/main)
        reset-to-remote = ''
          !f(){ set -e; \
            b="$1"; \
            if [ -z "$b" ]; then b=$(git rev-parse --abbrev-ref HEAD); fi; \
            if [ "$b" = master ] || [ "$b" = main ]; then \
              echo "ERROR: reset-to-remote nicht auf '$b' ausfuehren."; exit 1; \
            fi; \
            git fetch --all --prune; \
            git switch "$b"; \
            if git show-ref --verify --quiet "refs/remotes/origin/$b"; then \
              r="origin/$b"; \
            else \
              u=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true); \
              if [ -n "$u" ]; then r="$u"; else \
                echo "ERROR: Weder origin/$b noch upstream gefunden."; exit 1; fi; \
            fi; \
            git reset --hard "$r"; \
          }; f
        '';

        # Panic-Button: laufende Operationen abbrechen
        abort-op = ''
          !f(){ \
            set +e; \
            try(){ \
              op="$1"; shift; \
              "$@" >/dev/null 2>&1; \
              rc=$?; \
              if [ $rc -eq 0 ]; then \
                echo "OK: aborted $op"; \
                exit 0; \
              fi; \
            }; \
            try rebase      git rebase --abort; \
            try merge       git merge --abort; \
            try cherry-pick git cherry-pick --abort; \
            try revert      git revert --abort; \
            try am          git am --abort; \
            try bisect      git bisect reset; \
            echo "INFO: no in-progress operation detected."; \
          }; f
        '';
      };
    };
  };


  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    escapeTime = 0;
    historyLimit = 20000;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
    ];

    extraConfig = ''
      # --- Prefix ---------------------------------------------------
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix

      # --- Terminal capabilities ------------------------------------
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ',xterm-256color:RGB'
      set -g allow-passthrough on

      # --- General behaviour ----------------------------------------
      setw -g mode-keys vi
      set -g status-keys vi
      set -s escape-time 0
      set -g mouse on
      set -g history-limit 20000
      set -g base-index 1
      setw -g pane-base-index 1

      # --- Look & feel ----------------------------------------------
      set -g status-bg colour236
      set -g status-fg colour223
      set -g message-style fg=colour223,bg=colour239
      set -g pane-border-style fg=colour239
      set -g pane-active-border-style fg=colour111
      set -g status-left " ⎈ #S "
      set -g status-right " %Y-%m-%d %H:%M "

      # --- Copy / paste behaviour -----------------------------------
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      set -g set-clipboard on

      # --- Pane management ------------------------------------------
      bind - split-window -h -c "#{pane_current_path}"
      bind _ split-window -v -c "#{pane_current_path}"
      bind x kill-pane

      bind C-h select-pane -L
      bind C-j select-pane -D
      bind C-k select-pane -U
      bind C-l select-pane -R

      bind r source-file ~/.config/tmux/tmux.conf \; display "tmux.conf reloaded ✅"
      bind e split-window -v -c "#{pane_current_path}" "hx"
    '';
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


  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}

