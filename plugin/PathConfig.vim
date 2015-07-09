if exists("g:loaded_pathconfig") || &cp
	finish
endif
let g:loaded_pathconfig	= 1
let s:keepcpo           = &cpo
set cpo&vim
"""""""""""""""""""""""""""""""""""""""""""""

" global variables
if !exists('g:pathconfig_path_configs')
	let g:pathconfig_path_configs = []
endif

" autocmd
augroup PathConfigAutoCmds
	autocmd!
	autocmd BufEnter * call s:ApplyConfig()
augroup END

" functions
fun! ApplyConfig()
	echo g:pathconfig_path_configs
endfun

"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
