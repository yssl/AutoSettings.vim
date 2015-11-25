" File:         plugin/PathConfig.vim
" Description:  Automatically updates vim's local configuration depending on the current file path.
" Author:       yssl <http://github.com/yssl>
" License:      MIT License

if exists("g:loaded_autoconfig") || &cp
	finish
endif
let g:loaded_autoconfig	= 1
let s:keepcpo           = &cpo
set cpo&vim
"""""""""""""""""""""""""""""""""""""""""""""

" initialize python
python << EOF
import vim
import os, fnmatch
EOF

" global variables
if !exists('g:autoconfig_configs')
	let g:autoconfig_configs = []
endif

" autocmd
augroup AutoConfigAutoCmds
	autocmd!
	autocmd BufEnter * call s:ApplyConfig()
augroup END

" functions
fun! s:ApplyConfig()
python << EOF
filepath = vim.eval('expand(\'<afile>:p\')')
configs = vim.eval('g:autoconfig_configs')
matched = False
for patterns, config in configs:
	for pattern in patterns:
		if fnmatch.fnmatch(filepath, pattern):
			#print filepath, pattern

			if 'setlocals' in config:
				for setparam in config['setlocals']:
					vim.command('exec \'setlocal %s\''%setparam)

			if 'localmaps' in config:
				for mapdata in config['localmaps']:
					for mapcmd in mapdata[0]:
						vim.command('exec \'%s <buffer> %s %s\''%(mapcmd, mapdata[1], mapdata[2]))

			break

EOF
endfun

"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
