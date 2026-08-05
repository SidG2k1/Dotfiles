" NOTE: Full Neovim config staged at ~/.config/nvim-staged/ — when ready to switch:
"   brew install neovim
"   mv ~/.config/nvim-staged ~/.config/nvim
"   nvim  (first launch bootstraps lazy.nvim + ~30 plugins)
" then update ~/.zshrc aliases (v/vi/vim -> nvim) and EDITOR.

execute pathogen#infect()
filetype plugin indent on
set cm=blowfish2

let mapleader = " "

set backspace=indent,eol,start " Allows backspace on mac
syntax on
set shiftwidth=4 "proper shiftwidth
set tabstop=4 " number of visual spaces per TAB
set showmatch " highlight matching [{()}]
set incsearch " search as characters are entered
set hlsearch " highlight matches
set hidden
set smartcase "For ignoring lowercase when search except when uppercase
set nocompatible
" Try to put the indent level at the right place
set smartindent
set breakindent "wraps on same indent
" Keep vim files in the ~/.vim folder
set viminfo='100,h,n~/.vim/viminfo
" sets line number
set nu
set relativenumber
set display+=lastline " Stops @@@ at end line for long lines
set display+=truncate " Show @@@ only when line is truncated, not just at EOL

" Additive defaults (macOS-friendly)
set mouse=                          " disable mouse — terminal owns selection/scroll
set clipboard^=unnamed,unnamedplus

" Netrw cosmetics
let g:netrw_banner = 0
let g:netrw_liststyle = 3
set termguicolors
set scrolloff=5 sidescrolloff=8
set updatetime=300
set splitright splitbelow
set undofile
set undodir=~/.vim/undo//
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//

augroup AutoSaveFolds
  autocmd!
  autocmd BufWinLeave ?* silent! mkview
  autocmd BufWinEnter ?* silent! loadview
augroup END

if has("autocmd")
  augroup templates
    autocmd BufNewFile *.cpp 0r ~/.vim/templates/skeleton.cpp
    autocmd BufNewFile *.rmd 0r ~/.vim/templates/skeleton.rmd
    autocmd BufNewFile *.rkt 0r ~/.vim/templates/skeleton.rkt
    autocmd BufNewFile *.c 0r ~/.vim/templates/skeleton.c
    autocmd BufNewFile *.tex 0r ~/.vim/templates/skeleton.tex
  augroup END
endif


nnoremap QQ :q!<CR>
inoremap ;; <Esc>/(++)<Enter>ca)
nnoremap clr ggdG
nnoremap spc mtO<esc>jo<esc>`t
nnoremap call ggVG

" ALE settings (replaces syntastic; async)
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 'never'
let g:ale_set_loclist = 1
let g:ale_open_list = 0
nnoremap SR :ALEReset<CR>

" Airline (baseline — plugin was installed but unconfigured)
let g:airline#extensions#tabline#enabled = 0
let g:airline_powerline_fonts = 0
let g:airline_section_z = '%l/%L  %p%%'

nmap WW :w<CR>

autocmd FileType python nnoremap <PageDown><PageDown> :w<CR>:!python3 %<CR>
autocmd FileType cpp nnoremap <PageDown><PageDown> :w<CR>:!g++ %:S -o a.out && ./a.out; rm -f a.out<CR>
autocmd FileType c   nnoremap <PageDown><PageDown> :w<CR>:!gcc %:S -o a.out && ./a.out; rm -f a.out<CR>
autocmd FileType markdown nnoremap <PageDown><PageDown> :w<CR>:!pandoc -f markdown -t latex -s -o %.pdf %<CR><CR>
autocmd Filetype markdown nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A.pdf<esc>Iopen<space><esc>:.w<space>!bash<CR>
autocmd Filetype rmd nnoremap <PageDown><PageDown> :w<CR>:!echo<space>"require(rmarkdown);<space>render('<c-r>%')"<space>\|<space>R<space>--vanilla<CR>
autocmd Filetype rmd nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A<esc>F.C.pdf<esc>Iopen<space><esc>:.w<space>!bash<CR>
" PagueUp replacement: :! xdg-open %:r.pdf &<CR>

autocmd FileType python inoremap rip input("s")<esc>Fss

" autocmd Filetype tex nnoremap <PageUp><PageUp> :!basename % .tex|awk '{print $1".pdf"}'|xargs xdg-open
autocmd Filetype tex      nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A<esc>F.C.pdf<esc>Iopen<space><esc>:.w<space>!bash<CR><CR>dd
autocmd Filetype plaintex nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A<esc>F.C.pdf<esc>Iopen<space><esc>:.w<space>!bash<CR><CR>dd
" ^^^^ haven't figured out yet. Opens the pdf file of current thingy

augroup tex_maps
  autocmd!
  autocmd FileType tex,plaintex inoremap ;it \item
  autocmd FileType tex,plaintex inoremap ;nls \begin{enumerate}<esc>yyplcwend<esc>O<tab>
  autocmd FileType tex,plaintex inoremap ;ls \begin{itemize}<esc>yyplcwend<esc>O<tab>
  autocmd FileType tex,plaintex inoremap ;td \todo[fancyline]{(++)}<esc>2hca)
  autocmd FileType tex,plaintex inoremap ;lr( \left( q \right)(++)<esc>Fqs
  autocmd FileType tex,plaintex inoremap ;tx  \text{}(++)<esc>F}i
  autocmd FileType tex,plaintex inoremap ;ds \displaystyle{}<esc>i
  autocmd FileType tex,plaintex nnoremap <PageDown><PageDown> :w<CR>:!xelatex -shell-escape %:S<CR><CR>
  autocmd FileType tex,plaintex inoremap <C-S-l> $$<esc>i
  autocmd FileType tex,plaintex inoremap ;sc \section{}<Esc>o<Tab>(++)<Esc>kf}i
  autocmd FileType tex,plaintex inoremap ;ssc \subsection{}<Esc>o<Tab>(++)<Esc>kf}i
  autocmd FileType tex,plaintex inoremap ;sssc \subsubsection{}<Esc>o<Tab>(++)<Esc>kf}i
  autocmd FileType tex,plaintex inoremap ;ssssc \subsubsubsection{}<Esc>o<Tab>(++)<Esc>kf}i
  autocmd FileType tex,plaintex inoremap ;beg \begin{}  %;zf to end <enter>\end{(++)}<Enter>(++)<esc>kO<tab>(++)<esc>k0f{a
  autocmd FileType tex,plaintex inoremap ;fr \frac{}{(++)}<esc>F\f}i
  " extension to the ;beg command:
  autocmd FileType tex,plaintex inoremap ;zf <esc>hhf}lDhh"tyi}2j0f{"tplda)<esc>2kA
augroup END

autocmd FileType rmd inoremap <C-S-l> $$<esc>i

nnoremap ;th :ThesaurusQueryReplaceCurrentWord<CR>

set spell "Spellcheck
hi clear SpellBad
hi SpellBad cterm=underline
set wildmenu " visual autocomplete for command menu
