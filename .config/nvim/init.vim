" Neovim config — reuse the existing ~/.vim setup verbatim (same plugins, same
" theme, same mappings, the :Clean command). The move from vim to neovim is
" intentionally transparent: nothing about the editing experience changes.
"
" Why move at all: neovim renders terminal undercurls, so gruvbox's native
" spell marks (a blue squiggle under misspelled words) finally show. vim 9.1
" on this terminal could not emit underline/undercurl styles at all.
"
" Standard "share ~/.vim with nvim" idiom (see :help nvim-from-vim):
set runtimepath+=~/.vim
let &packpath = &runtimepath
source ~/.vimrc
