" File:         plugin/PathConfig.vim
" Description:  Automatically updates vim's local configuration depending on the current file path.
" Author:       yssl <http://github.com/yssl>
" License:      MIT License

if exists("g:loaded_autosettings") || &cp
	finish
endif
let g:loaded_autosettings	= 1
let s:keepcpo           = &cpo
set cpo&vim
"""""""""""""""""""""""""""""""""""""""""""""

" initialize python
python << EOF
import vim
import os, fnmatch

def getWinName(bufname, buftype):
	if bufname==None:
		if len(buftype)>0:
			winname = '[%s]'%buftype
		else:
			winname = '[No Name]'
	else:
		if len(buftype)>0:
			winname = os.path.basename(bufname)
			winname = '[%s] %s'%(buftype, winname)
		else:
			winname = bufname
	return winname

# config: python dictionary
# ex) {
#		\'localMaps':[
#			\[['nnoremap', 'inoremap', 'cnoremap', 'vnoremap'], '<F9>', ':w<CR>:BuildAndViewTexPdf<CR>:call QuickfixCWindowError()<CR><C-l><C-l>'],
#			\[['nnoremap', 'inoremap', 'cnoremap', 'vnoremap'], '<C-F9>', ':w<CR>:BuildTexPdf<CR>:call QuickfixCWindowError()<CR><C-l>'],
#			\[['nnoremap'], '<Leader>fs', ':call Tex_ForwardSearchLaTeX()<CR>'],
#		\],
#		\'setLocals':[
#			\'wrap',
#			\'shiftwidth=4',
#			\'expandtab',
#			\'makeprg=stdbuf\ -i0\ -o0\ -e0\ python\ %',
#		\],
#	\}
# 
# example for <expr> mapping - following two statements are identical
# exec 'nnoremap <buffer> <expr> <Leader>sc ":echo expand(\"%:p\")\<CR>"'
# exec 'nnoremap <buffer> <Leader>sc :echo expand("%:p")<CR>'
def applyConfig(config):
	if 'setLocals' in config:
		for setparam in config['setLocals']:
			vim.command('exec \'setlocal %s\''%setparam)
	if 'localMaps' in config:
		for mapdata in config['localMaps']:
			shortcut = mapdata[1]
			command = mapdata[2]
			for mapcmd in mapdata[0]:
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command = '<ESC>'+command
				vim.command('exec \'%s <buffer> %s %s\''%(mapcmd, shortcut, command))
	if 'localMapsExpr' in config:
		for mapdata in config['localMapsExpr']:
			shortcut = mapdata[1]
			command = mapdata[2]
			for mapcmd in mapdata[0]:
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command = command[:1]+'<ESC>'+command[1:]
				vim.command('exec \'%s <buffer> <expr> %s \'%s\'\''%(mapcmd, shortcut, command))

matched_local_patterns = []
matched_local_configs = []
matched_build_pattern = ''
matched_build_config = {}
current_pattern_configname = {}
EOF

" global variables
if !exists('g:autosettings_for_local')
	let g:autosettings_for_local = []
endif
if !exists('g:autosettings_for_build')
	let g:autosettings_for_build = []
endif

" commands
command! AutoSettingsPrint call s:PrintCurrentConfig()

" autocmd
augroup AutoSettingsAutoCmds
	autocmd!
	autocmd BufEnter * call s:UpdateConfig()
augroup END

" functions
fun! s:UpdateConfig()
python << EOF
filepath = vim.eval('expand(\'<afile>:p\')')
del matched_local_patterns[:]
del matched_local_configs[:]
matched_build_pattern = ''
matched_build_config = {}

# localconfigs
localconfigs = vim.eval('g:autosettings_for_local')
for patterns, config in localconfigs:
	for pattern in patterns:
		if fnmatch.fnmatch(filepath, pattern):
			matched_local_patterns.append(pattern)
			matched_local_configs.append(config)
			applyConfig(config)
			break

# buildconfigs
buildconfigs = vim.eval('g:autosettings_for_build')
matched = False
for patterns, config in buildconfigs:
	for pattern in patterns:
		if fnmatch.fnmatch(filepath, pattern):
			matched_build_pattern = pattern
			matched_build_config = config

			# common config
			if 'commonConfig' in config:
				applyConfig(config['commonConfig'])

			# specific config
			if pattern not in current_pattern_configname:
				current_configname = config['defaultConfigName']
				current_pattern_configname[pattern] = current_configname

			current_config = config['configs'][current_configname]
			#print current_config

			applyConfig(current_config)

			matched = True
			break
	if matched:
		break
EOF
endfun

fun! s:PrintCurrentConfig()
python << EOF
bufname = vim.current.buffer.name
buftype = vim.eval('getbufvar(winbufnr("%"), \'&buftype\')')
winname = getWinName(bufname, buftype)
print 'AutoSettings.vim settings for: %s'%winname
print ' '

print 'Matched Local Config Patterns:'
for i in range(len(matched_local_patterns)):
	print matched_local_patterns[i]
	print matched_local_configs[i]
print ' '

print 'Matched Build Config Pattern:'
print matched_build_pattern
print ' '

print 'Predefined Config Names in the Matched Pattern:'
if 'configNames' in matched_build_config:
	print matched_build_config['configNames']
print ' '

print 'Current Config Name for the Matched Pattern:'
if matched_build_pattern in current_pattern_configname:
	current_config_name = current_pattern_configname[matched_build_pattern]
	print current_config_name
print ' '

print 'Current Build Config:'
if 'configs' in matched_build_config:
	print matched_build_config['configs'][current_config_name]
print ' '
EOF
endfun

"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
