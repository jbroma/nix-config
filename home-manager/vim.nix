{ 
  pkgs, 
  lib, 
  ... 
}: 

{
  programs.vim = { 
    enable = true; 
    settings = {
      background = "dark";
      mouse = "a";
      number = true;
    };
    extraConfig = ''
      set encoding=utf-8
      syntax on
      "Custom highlight groups
      highlight BadWhitespace ctermbg=red 
      highlight ColorColumn ctermbg=0

      "Backspace fix
      set backspace=indent,eol,start
      "Unified clipboard
      inoremap <C-v> <ESC>"+pa
      vnoremap <C-c> "+y
      set clipboard=unnamedplus

      "Flag Unnecessary Whitespace in given filetypes
      au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.cpp,*.hpp match BadWhitespace /\s\+$/

      "***Language specific settings***
      "Python indentation
      au BufNewFile,BufRead *.py
      \ set tabstop=4 |
      \ set softtabstop=4 |
      \ set shiftwidth=4 |
      \ set textwidth=79 |
      \ set expandtab |
      \ set autoindent |
      \ set fileformat=unix

      "YAML indentation
      au FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
    ''
  };
}