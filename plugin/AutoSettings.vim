" File:         plugin/AutoSettings.vim
" Description:  Automatically updates vim local settings depending on current file path and user-defined build configurations.
" Author:       yssl <http://github.com/yssl>
" License:      MIT License

if exists("g:loaded_autosettings") || &cp
	"finish
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
	'command':'Executed Commands (Up to Down)',
	}

categories = ['setLocals','localMaps','localMapsExpr','buildConfigNames','buildConfig']

def buildCurrentSettingMat(colTypes):
	mat = []
	mat.append([colLabelsd[type] for type in colTypes])

	for p in range(len(gMatchedPatterns)):	# p: pattern inex
		pattern = gMatchedPatterns[p]
		setting = gMatchedSettings[p]

		isFirstCategory = True
		for category in categories:
			if category in setting:
				categoryData = setting[category]

				if category=='buildConfigNames':
					itemData = categoryData

					row = []

					# add pattern
					if isFirstCategory:
						row.append(pattern)	# store pattern
					else:
						row.append('')

					# add category
					row.append(category)

					# add command
					row.append(itemData2Str(category, itemData))

					mat.append(row)

				else:
					for i in range(len(categoryData)):	# i: item index
						itemData = categoryData[i]

						row = []

						# add pattern
						if isFirstCategory and i==0:
							row.append(pattern)	# store pattern
						else:
							row.append('')

						# add category
						if i==0:
							row.append(category)
						else:
							row.append('')

						# add command
						row.append(itemData2Str(category, itemData))

						mat.append(row)

				isFirstCategory = False

	return mat

def itemData2Str(category, itemData):
	if category=='setLocals':
		return 'setlocal %s'%itemData
	elif category=='localMaps':
		s = '['
		for i in range(len(itemData[0])):
			s += itemData[0][i]
			if i < len(itemData[0])-1:
				s += ' '
		s += '] <buffer> %s %s'%(itemData[1], itemData[2])
		return s
	elif category=='localMapsExpr':
		s = '['
		for i in range(len(itemData[0])):
			s += itemData[0][i]
			if i < len(itemData[0])-1:
				s += ' '
		#cmd = itemData[2]
		cmd = repr(itemData[2])
		cmd = cmd.replace('\\','\\\\')
		cmd = cmd.replace('\'','\\\'')
		s += '] <buffer> <expr> %s \'%s\''%(itemData[1], cmd)
		return s
	elif category=='buildConfigNames':
		s = '['
		for i in range(len(itemData)):
			s += itemData[i]
			if i < len(itemData)-1:
				s += ' '
		s += ']'
		return s
	else:
		return str(itemData)

def toWidthColMat(rowMat):
	colMat = [[None]*len(rowMat) for c in range(len(rowMat[0]))]
	for r in range(len(rowMat)):
		for c in range(len(rowMat[r])):
			colMat[c][r] = len(rowMat[r][c])
	return colMat

gMatchedPatterns = []
gMatchedSettings = []
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
del gMatchedPatterns[:]
del gMatchedSettings[:]

localsettings = vim.eval('g:autosettings_settings')
for patterns, setting in localsettings:
	for pattern in patterns:
		if fnmatch.fnmatch(filepath, pattern):
			gMatchedPatterns.append(pattern)
			gMatchedSettings.append(setting)

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
vim.command('echon \'AutoSettings for \'')
vim.command('echohl Title')
vim.command('echon \'%s\''%winname)
vim.command('echohl None')
vim.command('echon \':\'')
vim.command('echo \' \'')

#for i in range(len(gMatchedPatterns)):
#	print gMatchedPatterns[i]
#	print gMatchedSettings[i]
#print ' '

colTypes = ['pattern', 'category', 'command']
dataMat = buildCurrentSettingMat(colTypes)

#for r in range(len(dataMat)):
#	for c in range(len(dataMat[0])):
#		print dataMat[r][c],
#	print

widthColMat = toWidthColMat(dataMat)

maxColWidths = []
gapWidth = 2
for c in range(len(colTypes)):
	maxColWidth = max(widthColMat[c]) + gapWidth
	maxColWidths.append(maxColWidth)

# print
prefix = '..'
for r in range(len(dataMat)):
	if r==0:	vim.command('echohl Title')
	s = ''
	for c in range(len(dataMat[0])):
		s += dataMat[r][c].ljust(maxColWidths[c])
	vim.command('echo \'%s\''%s)
	if r==0:	vim.command('echohl None')

EOF
endfun


"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
