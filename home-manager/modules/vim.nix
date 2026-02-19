{ config, pkgs, lib, inputs, ... }:

{
  programs.vim = {
    enable = true;
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
}
