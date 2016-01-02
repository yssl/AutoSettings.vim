" File:         plugin/AutoSettings.vim
" Description:  Automatically updates vim local settings depending on current file path and user-defined build configurations.
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

# setting: vimscript dictionary
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
def applySetting(setting):
	if 'setLocals' in setting:
		for setparam in setting['setLocals']:
			vim.command('exec \'setlocal %s\''%setparam)
	if 'localMaps' in setting:
		for mapdata in setting['localMaps']:
			shortcut = mapdata[1]
			command = mapdata[2]
			for mapcmd in mapdata[0]:
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command = '<ESC>'+command
				vim.command('exec \'%s <buffer> %s %s\''%(mapcmd, shortcut, command))
	if 'localMapsExpr' in setting:
		for mapdata in setting['localMapsExpr']:
			shortcut = mapdata[1]
			command = mapdata[2]
			for mapcmd in mapdata[0]:
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command = command[:1]+'<ESC>'+command[1:]
				vim.command('exec \'%s <buffer> <expr> %s \'%s\'\''%(mapcmd, shortcut, command))

def applyBuildConfig(setting):
	if 'buildConfigNames' in setting:
		pass
	if 'buildConfigs' in setting:
		current_configname = setting['buildConfigNames'][0]
		current_config = setting['buildConfigs'][current_configname]
		applySetting(current_config)


colLabelsd = {
	'pattern':'Pattern',
	'category':'Category',
	'command':'Command',
	}

def buildCurrentSettingMat(colTypes):
	mat = []
	mat.append([colLabelsd[type] for type in colTypes])

	for i in range(len(matched_local_patterns)):
		row = []
		row.append(matched_local_patterns[i])	# store pattern


		mat.append(row)


	for r in range(len(vim.windows)):
		vim.command(str(r+1)+'wincmd w')
		vim.command('call add(mat, [])')

		if vim.windows[r]==curwin:
			curwin_r = r

		bufname = vim.windows[r].buffer.name
		buftype = vim.eval('getbufvar(winbufnr(winnr()), \'&buftype\')')

		for type in propTypes:
			if type=='iscurwin':
				if vim.windows[r]==curwin:	strcurwin = '* '
				else:						strcurwin = '  '
				vim.command('call add(mat[-1], \'%s\')'%strcurwin)

			elif type=='winnr':
				vim.command('call add(mat[-1], \'%s\')'%str(r+1))

			elif type=='winname':
				vim.command('call add(mat[-1], \'%s\')'%getWinName(bufname, buftype))

			elif type=='workdir':
				dir = vim.eval('s:GetWorkDir(\'%s\')'%getWinName(bufname, buftype))
				#print '|%s|%s|%s|'%(bufname,buftype,dir)
				vim.command('call add(mat[-1], \'%s\')'%dir)

			elif type=='workdir_pattern':
				pattern = vim.eval('s:GetWorkDirPattern(\'%s\')'%getWinName(bufname, buftype))
				vim.command('call add(mat[-1], \'%s\')'%pattern)

	vim.command(str(curwin_r+1)+'wincmd w')
	vim.command('return mat')

matched_local_patterns = []
matched_local_settings = []
EOF

" global variables
if !exists('g:autosettings_settings')
	let g:autosettings_settings = []
endif
if !exists('g:autosettings_for_build')
	let g:autosettings_for_build = []
endif

" commands
command! AutoSettingsPrint call s:PrintCurrentSetting()

" autocmd
augroup AutoSettingsAutoCmds
	autocmd!
	autocmd BufEnter * call s:UpdateSetting()
augroup END

" functions
fun! s:UpdateSetting()
python << EOF
filepath = vim.eval('expand(\'<afile>:p\')')
del matched_local_patterns[:]
del matched_local_settings[:]

localsettings = vim.eval('g:autosettings_settings')
for patterns, setting in localsettings:
	for pattern in patterns:
		if fnmatch.fnmatch(filepath, pattern):
			matched_local_patterns.append(pattern)
			matched_local_settings.append(setting)

			# process 'setLocals', 'localMaps', 'localMapsExpr'
			applySetting(setting)

			# process 'buildConfigNames', 'buildConfigs'
			applyBuildConfig(setting)

			break
EOF
endfun

fun! s:PrintCurrentSetting()
python << EOF
bufname = vim.current.buffer.name
buftype = vim.eval('getbufvar(winbufnr("%"), \'&buftype\')')
winname = getWinName(bufname, buftype)
print 'AutoSettings.vim settings for: %s'%winname
print ' '

for i in range(len(matched_local_patterns)):
	print matched_local_patterns[i]
	print matched_local_settings[i]
print ' '



colTypes = ['pattern', 'category', 'command']

EOF


"wpMat = vim.eval('s:BuildAllWinPropMat(propTypes)')
"propTypes = vim.eval('propTypes')

"# build width info
"vimWidth = int(vim.eval('&columns'))
"widthColMat = toWidthColMat(wpMat)

"widths = []
"len_labels = int(vim.eval('len(propTypes)'))
"sumLongWidths = 0
"for c in range(len_labels):
	"if c==0:	gapWidth = 0
	"else:		gapWidth = 2
	"maxColWidth = max(widthColMat[c]) + gapWidth
	"widths.append(maxColWidth)

	"if propTypes[c]=='winname' or propTypes[c]=='workdir':
		"sumLongWidths += maxColWidth

"totalWidth = sum(widths)
"reduceWidth = totalWidth - vimWidth
"if reduceWidth > 0:
	"for c in range(len_labels):
		"if propTypes[c]=='winname' or propTypes[c]=='workdir':
			"widths[c] -= int(reduceWidth * float(widths[c])/sumLongWidths)+1

"# print
"prefix = '..'
"for r in range(len(wpMat)):
	"if r==0:	vim.command('echohl Title')
	"s = ''
	"for c in range(len(wpMat[0])):
		"if len(wpMat[r][c])<=widths[c]:
			"s += wpMat[r][c].ljust(widths[c])
		"else:
			"s += ltrunc(wpMat[r][c], widths[c]-2, prefix)+'  '
	"vim.command('echo \'%s\''%s)
	"if r==0:	vim.command('echohl None')

"# prompt
"message = 'Type # of window to jump to or press ENTER to exit'
"vim.command('call inputsave()')
"vim.command("let user_input = input('" + message + ": ')")
"vim.command('call inputrestore()')
"user_input = vim.eval('user_input')
"if user_input.isdigit():
	"winidx = int(user_input)
	"winnum = int(vim.eval('winnr("$")'))
	"if winidx<=winnum:
		"vim.command('%dwincmd w'%winidx)

endfun

"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
