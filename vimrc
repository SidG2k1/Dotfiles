execute pathogen#infect()
filetype plugin indent on
set cm=blowfish2

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

augroup AutoSaveFolds
  autocmd!
  autocmd BufWinLeave * mkview
  autocmd BufWinEnter * silent! loadview
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


nnoremap call GVgg
nnoremap QQ :q!<CR>
inoremap ;; <Esc>/(++)<Enter>ca)
nnoremap clr ggdG
nnoremap spc mtO<esc>jo<esc>`t

" Synastic Settings
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
nnoremap SR :SyntasticReset<CR>
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

nmap WW :w<CR>

autocmd FileType python nnoremap <PageDown><PageDown> :w<CR>:!python3 %<CR>
autocmd FileType cpp nnoremap <PageDown><PageDown> :w<CR>:!g++ %;echo "---Start---">temprm;cat temprm;./a.out;rm a.out;echo ' '>temprm;cat temprm;echo "--- End ---">temprm;cat temprm;rm temprm<CR>
autocmd FileType c nnoremap <PageDown><PageDown> :w<CR>:!gcc % -o a.out;echo "---Start---">temprm;cat temprm;./a.out;rm a.out;echo ' '>temprm;cat temprm;echo "--- End ---">temprm;cat temprm;rm temprm<CR>
autocmd FileType markdown nnoremap <PageDown><PageDown> :w<CR>:!pandoc -f markdown -t latex -s -o %.pdf %<CR><CR>
autocmd Filetype markdown nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A.pdf<esc>Ixdg-open<space><esc>:.w<space>!bash<CR>
autocmd Filetype rmd nnoremap <PageDown><PageDown> :w<CR>:!echo<space>"require(rmarkdown);<space>render('<c-r>%')"<space>\|<space>R<space>--vanilla<enter>
autocmd Filetype rmd nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A<esc>F.C.pdf<esc>Ixdg-open<space><esc>:.w<space>!bash<CR>
" PagueUp replacement: :! xdg-open %:r.pdf &<CR>

autocmd FileType python inoremap rip raw_input("s")<esc>Fss

" autocmd Filetype tex nnoremap <PageUp><PageUp> :!basename % .tex|awk '{print $1".pdf"}'|xargs xdg-open
autocmd Filetype tex      nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A<esc>F.C.pdf<esc>Ixdg-open<space><esc>:.w<space>!bash<CR><CR>dd
autocmd Filetype plaintex nnoremap <PageUp><PageUp> :put<space>=expand('%:p')<CR>A<esc>F.C.pdf<esc>Ixdg-open<space><esc>:.w<space>!bash<CR><CR>dd
" ^^^^ haven't figured out yet. Opens the pdf file of current thingy

autocmd FileType plaintex inoremap ;it \item 
autocmd FileType tex inoremap ;it \item 

autocmd FileType plaintex inoremap ;nls \begin{enumerate}<esc>yyplcwend<esc>O<tab>
autocmd FileType tex inoremap ;nls \begin{enumerate}<esc>yyplcwend<esc>O<tab>

autocmd FileType plaintex inoremap ;ls \begin{itemize}<esc>yyplcwend<esc>O<tab>
autocmd FileType tex inoremap ;ls \begin{itemize}<esc>yyplcwend<esc>O<tab>

autocmd FileType tex inoremap ;td \todo[fancyline]{(++)}<esc>2hca)
autocmd FileType plaintex inoremap ;td \todo[fancyline]{(++)}<esc>2hca)

autocmd FileType tex inoremap ;lr( \left( q \right)(++)<esc>Fqs
autocmd FileType plaintex inoremap ;lr( \left( q \right)(++)<esc>Fqs

autocmd FileType tex inoremap ;tx  \text{}(++)<esc>F}i
autocmd FileType plaintex inoremap ;tx  \text{}(++)<esc>F}i

autocmd FileType tex inoremap ;ds \displaystyle{}<esc>i
autocmd FileType plaintex inoremap ;ds \displaystyle{}<esc>i

autocmd FileType tex nnoremap <PageDown><PageDown> :w<CR>:!xelatex -shell-escape %<CR><CR>
autocmd FileType plaintex nnoremap <PageDown><PageDown> :w<CR>:!xelatex -shell-escape %<CR><CR>

autocmd FileType tex inoremap <C-S-l> $$<esc>i
autocmd FileType plaintex inoremap <C-S-l> $$<esc>i

autocmd FileType tex inoremap ;sc \section{}<Esc>o<Tab>(++)<Esc>kf}i
autocmd FileType plaintex inoremap ;sc \section{}<Esc>o<Tab>(++)<Esc>kf}i

autocmd FileType tex inoremap ;ssc \subsection{}<Esc>o<Tab>(++)<Esc>kf}i
autocmd FileType plaintex inoremap ;ssc \subsection{}<Esc>o<Tab>(++)<Esc>kf}i

autocmd FileType tex inoremap ;sssc \subsubsection{}<Esc>o<Tab>(++)<Esc>kf}i
autocmd FileType plaintex inoremap ;sssc \subsubsection{}<Esc>o<Tab>(++)<Esc>kf}i

autocmd FileType tex inoremap ;ssssc \subsubsubsection{}<Esc>o<Tab>(++)<Esc>kf}i
autocmd FileType plaintex inoremap ;ssssc \subsubsubsection{}<Esc>o<Tab>(++)<Esc>kf}i

autocmd filetype tex inoremap ;beg \begin{}  %;zf to end <enter>\end{(++)}<Enter>(++)<esc>kO<tab>(++)<esc>k0f{a
autocmd filetype plaintex inoremap ;beg \begin{}%";zf" to end<enter>\end{(++)}<Enter>(++)<esc>kO<tab>(++)<esc>k0f{a

autocmd filetype tex inoremap ;fr \frac{}{(++)}<esc>F\f}i
autocmd filetype plaintex inoremap ;fr \frac{}{(++)}<esc>F\f}i

" extensions to the ;beg command:
autocmd filetype tex inoremap ;zf <esc>hhf}lDhh"tyi}2j0f{"tplda)<esc>2kA
autocmd filetype plaintex inoremap ;zf <esc>hhf}lDhh"tyi}2j0f{"tplda)<esc>2kA

autocmd FileType rmd inoremap <C-S-l> $$<esc>i

nnoremap ;th :ThesaurusQueryReplaceCurrentWord<CR>

nnoremap Y y$
set spell "Spellcheck
hi clear SpellBad
hi SpellBad cterm=underline
set wildmenu " visual autocomplete for command menu
