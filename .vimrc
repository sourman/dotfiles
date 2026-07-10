" Plugins
call plug#begin('~/.vim/plugged')

" File tree browser
Plug 'preservim/nerdtree'

" Fuzzy file finder (requires fzf installed)
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git integration
Plug 'tpope/vim-fugitive'

" Status bar
Plug 'vim-airline/vim-airline'

" Syntax highlighting for tons of languages
Plug 'sheerun/vim-polyglot'

" CSV file support
Plug 'chrisbra/csv.vim'

" Color scheme
Plug 'morhetz/gruvbox'

call plug#end()

" Settings
set nowrap
set textwidth=70
set formatoptions+=t
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set ignorecase
set smartcase
set incsearch
set hlsearch
set splitright
set splitbelow
set clipboard=unnamedplus
set hidden

" Theme — termguicolors makes gruvbox render in true color, and its undercurl
" spell-marks (gui=undercurl guisp=...) actually show. Set these BEFORE the
" colorscheme so gruvbox initializes for dark/truecolor.
set termguicolors
set background=dark
colorscheme gruvbox

" Spell marks. Neovim renders terminal undercurls (vim 9.1 on this terminal
" could not), so gruvbox's native SpellBad — a blue squiggly undercurl — shows
" as-is with no override. SpellCap (words vim thinks should be capitalized) is
" silenced: it flags ordinary lowercase words (e.g. after a period) and is noisy.
augroup vimrc_spell
  autocmd!
  autocmd ColorScheme * highlight SpellCap NONE
augroup END
highlight SpellCap NONE

" NERDTree: toggle with Ctrl+n
nnoremap <C-n> :NERDTreeToggle<CR>

" FZF: find files with Ctrl+p
nnoremap <C-p> :FZF<CR>

" Spell check — OFF by default, so it doesn't squiggle camelCase identifiers in
" code and JSON. ON only for git commit/merge messages (the gitcommit filetype),
" where the text is prose and spell-checking is genuinely useful.
autocmd FileType gitcommit setlocal spell

" :Clean — toggle a distraction-free "focus" mode in the current window.
" Hides line numbers, the sign/fold gutter and listchars, so selecting text to
" copy is clean (no number column or spacing around what you grab). Run :Clean
" again to restore. Options are window-local, so it only affects this window
" and remembers each window's prior state.
function! CleanModeToggle() abort
  if !exists('w:clean_mode') || !w:clean_mode
    let w:clean_restore = {
          \ 'number':         &number,
          \ 'relativenumber': &relativenumber,
          \ 'signcolumn':     &signcolumn,
          \ 'foldcolumn':     &foldcolumn,
          \ 'list':           &list}
    setlocal nonumber norelativenumber signcolumn=no foldcolumn=0 nolist
    let w:clean_mode = 1
    echo 'Clean mode on'
  else
    let &l:number         = w:clean_restore.number
    let &l:relativenumber = w:clean_restore.relativenumber
    let &l:signcolumn     = w:clean_restore.signcolumn
    let &l:foldcolumn     = w:clean_restore.foldcolumn
    let &l:list           = w:clean_restore.list
    unlet w:clean_mode w:clean_restore
    echo 'Clean mode off'
  endif
endfunction
command! Clean call CleanModeToggle()
" vim requires user commands to start with an uppercase letter (E183), so the
" command is :Clean — but this lets you type :clean too. Guarded so it only
" fires when the whole command line is exactly "clean" (so :clist, :close, and
" :%s/clean/... are never affected). :clean is not a built-in (E492) and no
" plugin defines it, so there's nothing to collide with.
cnoreabbrev <expr> clean (getcmdtype() ==# ':' && getcmdline() ==# 'clean') ? 'Clean' : 'clean'
