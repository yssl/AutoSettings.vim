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
	'command':'Vim Commands (executed from top to bottom)',
	}

categories = ['setLocals','localMaps','localMapsExpr','buildConfigNames','buildConfig']

def buildCurrentSettingMat(colTypes):
	mat = [] # num row * num cols
	mat.append([colLabelsd[type] for type in colTypes])

	itemKeywordPositions = [[0,0]]	# num row

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
					itemStr, keywordPositions = itemData2Str(category, itemData)
					row.append(itemStr)

					mat.append(row)
					itemKeywordPositions.append(keywordPositions)

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
						itemStr, keywordPositions = itemData2Str(category, itemData)
						row.append(itemStr)

						mat.append(row)
						itemKeywordPositions.append(keywordPositions)

				isFirstCategory = False

	return mat, itemKeywordPositions

def itemData2Str(category, itemData):
	cmd = ''
	shortcut = ''
	contents = ''
	keywordPositions = [0,0]	# [0]:end pos of vim command, [1]:end pos of shortcut

	if category=='setLocals':
		cmd = 'setlocal '
		contents = itemData
	elif category=='localMaps':
		cmd = '['
		for i in range(len(itemData[0])):
			cmd += itemData[0][i]
			if i < len(itemData[0])-1:
				cmd += ' '
		cmd += '] <buffer> '
		shortcut = itemData[1]+' '
		contents = itemData[2]
	elif category=='localMapsExpr':
		cmd = '['
		for i in range(len(itemData[0])):
			cmd += itemData[0][i]
			if i < len(itemData[0])-1:
				cmd += ' '
		cmd += '] <buffer> <expr> '
		shortcut = itemData[1]+' '
		
		#contents = itemData[2]
		contents = repr(itemData[2])
		contents = contents.replace('\\','\\\\')
		contents = contents.replace('\'','\\\'')
		contents = '\'%s\''%contents
	elif category=='buildConfigNames':
		contents = '['
		for i in range(len(itemData)):
			contents += itemData[i]
			if i < len(itemData)-1:
				contents += ' '
		contents += ']'
	else:
		contents = str(itemData)

	itemStr = cmd + shortcut + contents
	keywordPositions = [len(cmd), len(cmd)+len(shortcut)]

	return itemStr, keywordPositions

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
hlGroupsd = {
			'title':'Title',
			'labels':'Title',
			'pattern':'Identifier',
			'setLocals':'PreProc',
			'localMaps':'Type','localMapsExpr':'Type',
			'buildConfigNames':'Number','buildConfig':'Number',
			'shortcut':'Function',
			'contents':'None'
			}

bufname = vim.current.buffer.name
buftype = vim.eval('getbufvar(winbufnr("%"), \'&buftype\')')
winname = getWinName(bufname, buftype)
vim.command('echohl %s'%hlGroupsd['title'])
vim.command('echon \'AutoSettings \'')
vim.command('echohl None')
vim.command('echon \'for \'')
vim.command('echon \'%s\''%winname)
vim.command('echon \':\'')
vim.command('echo \' \'')

#for i in range(len(gMatchedPatterns)):
#	print gMatchedPatterns[i]
#	print gMatchedSettings[i]
#print ' '

colTypes = ['pattern', 'category', 'command']
dataMat, itemKeywordPositions = buildCurrentSettingMat(colTypes)

if len(dataMat) > 1:

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
	categoryColor = 'None'
	for r in range(len(dataMat)):
		if r==0:
			vim.command('echo \'\'')
			vim.command('echohl %s'%hlGroupsd['labels'])
			s = ''
			for c in range(len(dataMat[0])):
				s += dataMat[r][c].ljust(maxColWidths[c])
			vim.command('echon \'%s\''%s)
		else:
			for c in range(len(dataMat[0])):
				if c==0:
					vim.command('echohl %s'%hlGroupsd['pattern'])
					vim.command('echon \'%s\''%dataMat[r][c].ljust(maxColWidths[c]))
				elif c==1:
					if dataMat[r][c] in hlGroupsd:
						categoryColor = hlGroupsd[dataMat[r][c]]
						vim.command('echohl %s'%categoryColor)
					vim.command('echon \'%s\''%dataMat[r][c].ljust(maxColWidths[c]))
				else:
					#vim.command('echohl %s'%hlGroupsd[''])
					#vim.command('echon \'%s\''%dataMat[r][c].ljust(maxColWidths[c]))
					itemStr = dataMat[r][c].ljust(maxColWidths[c])
					vim.command('echohl %s'%categoryColor)
					vim.command('echon \'%s\''%itemStr[:itemKeywordPositions[r][0]])
					vim.command('echohl %s'%hlGroupsd['shortcut'])
					vim.command('echon \'%s\''%itemStr[itemKeywordPositions[r][0]:itemKeywordPositions[r][1]])
					vim.command('echohl %s'%hlGroupsd['contents'])
					vim.command('echon \'%s\''%itemStr[itemKeywordPositions[r][1]:])

		vim.command('echo \'\'')

else:
	vim.command('echohl %s'%hlGroupsd['labels'])
	vim.command('echo \'No matching patterns for the current window.\'')	

vim.command('echohl None')

EOF

		"if r==0:	vim.command('echohl Title')
		"s = ''
		"for c in range(len(dataMat[0])):
			"s += dataMat[r][c].ljust(maxColWidths[c])
		"vim.command('echo \'%s\''%s)
		"if r==0:	vim.command('echohl None')


endfun


"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
