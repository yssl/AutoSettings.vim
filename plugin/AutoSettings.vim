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
					command2 = '<ESC>'+command
				else:
					command2 = command
				vim.command('exec \'%s <buffer> %s %s\''%(mapcmd, shortcut, command2))
	if 'localMapsExpr' in setting:
		for mapdata in setting['localMapsExpr']:
			shortcut = mapdata[1]
			command = mapdata[2]
			for mapcmd in mapdata[0]:
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command2 = command[:1]+'<ESC>'+command[1:]
				else:
					command2 = command
				vim.command('exec \'%s <buffer> <expr> %s \'%s\'\''%(mapcmd, shortcut, command2))

def applyBuildConfig(setting):
	if 'buildConfigNames' in setting:
		pass
	if 'buildConfigs' in setting:
		current_configname = setting['buildConfigNames'][0]
		current_config = setting['buildConfigs'][current_configname]
		applySetting(current_config)

colTypes = ['pattern', 'category', 'command']
colLabelsd = {
	'pattern':'Pattern',
	'category':'Category',
	'command':'Vim Commands (executed from top to bottom)',
	}

def buildSettingMats(pattern, setting, configName):

	# dataMat[i][0]: pattern
	# dataMat[i][1]: category
	# dataMat[i][2]: vim command
	dataMat = []

	# posMat[i][1]: end pos of configName
	# posMat[i][2][0]: end pos of vim command (like 'setlocal')
	# posMat[i][2][1]: end pos of shortcut
	# posMat[i][2][2]: start pos of <ESC>
	# posMat[i][2][3]: end pos of <ESC>
	posMat = []

	if 'setLocals' in setting:
		for i in range(len(setting['setLocals'])):
			if i==0:
				category = 'setLocals'
			else:
				category = ''
			setparam = setting['setLocals'][i]
			vim_command = 'setlocal %s'%setparam
			dataMat.append(['',category,vim_command])
			posMat.append([None, 0, [8, 8, 8, 8]])
	if 'localMaps' in setting:
		for i in range(len(setting['localMaps'])):
			mapdata = setting['localMaps'][i]
			shortcut = mapdata[1]
			command = mapdata[2]
			for j in range(len(mapdata[0])):
				if i==0 and j==0:
					category = 'localMaps'
				else:
					category = ''
				mapcmd = mapdata[0][j]
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command2 = '<ESC>'+command
					lenEsc = 5
				else:
					command2 = command
					lenEsc = 0
				vim_command = '%s <buffer> %s %s'%(mapcmd, shortcut, command2)
				dataMat.append(['',category,vim_command])
				endPosCmd = len(mapcmd)+9
				endPosScut = endPosCmd+len(shortcut)+1
				startPosEsc = endPosScut
				endPosEsc = startPosEsc + lenEsc+1
				posMat.append([None, 0, [endPosCmd, endPosScut, startPosEsc, endPosEsc]])
	if 'localMapsExpr' in setting:
		for i in range(len(setting['localMapsExpr'])):
			mapdata = setting['localMapsExpr'][i]
			shortcut = mapdata[1]
			command = mapdata[2]
			for j in range(len(mapdata[0])):
				if i==0 and j==0:
					category = 'localMapsExpr'
				else:
					category = ''
				mapcmd = mapdata[0][j]
				if mapcmd[0]!='n':	# add <ESC> when non-normal mode mapping
					command2 = command[:1]+'<ESC>'+command[1:]
					lenEsc = 5
				else:
					command2 = command
					lenEsc = 0

				command2 = repr(command2)
				command2 = command2.replace('\\','\\\\')
				command2 = command2.replace('\'','\\\'')
				#command2 = '\'%s\''%command2

				vim_command = '%s <buffer> <expr> %s \'%s\''%(mapcmd, shortcut, command2)
				dataMat.append(['',category,vim_command])
				endPosCmd = len(mapcmd)+9+7
				endPosScut = endPosCmd+len(shortcut)+1
				startPosEsc = endPosScut
				endPosEsc = endPosScut
				posMat.append([None, 0, [endPosCmd, endPosScut, startPosEsc, endPosEsc]])

	if len(dataMat) > 0:
		dataMat[0][0] = pattern

	if configName != '':
		for r in range(len(dataMat)):
			if dataMat[r][1] != '':
				dataMat[r][1] = '['+configName+']'+dataMat[r][1]
				posMat[r][1] = len(configName)+2

	return dataMat, posMat

def buildBuildConfigMats(pattern, setting):
	if 'buildConfigNames' in setting:
		pass
	if 'buildConfigs' in setting:
		current_configname = setting['buildConfigNames'][0]
		current_config = setting['buildConfigs'][current_configname]
		return buildSettingMats(pattern, current_config, current_configname)
	return [],[]

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
			'esc':'Comment',
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

dataMat = []
posMat = []
dataMat.append([colLabelsd[type] for type in colTypes])
posMat.append([None, 0, [0,0,0,0]])

for i in range(len(gMatchedPatterns)):

	dm, pm = buildSettingMats(gMatchedPatterns[i], gMatchedSettings[i], '')
	dataMat.extend(dm)
	posMat.extend(pm)

	dm_config, pm_config = buildBuildConfigMats(gMatchedPatterns[i], gMatchedSettings[i])
	if len(dm)>0 and len(dm_config)>0:
		dm_config[0][0] = ''	# remove pattern
	dataMat.extend(dm_config)
	posMat.extend(pm_config)

if len(dataMat) > 1:

	#	for r in range(len(dataMat)):
	#		for c in range(len(dataMat[0])):
	#			print dataMat[r][c],
	#		print

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
					#vim.command('echon \'%s\''%dataMat[r][c].ljust(maxColWidths[c]))

					categoryStr = dataMat[r][c].ljust(maxColWidths[c])

					vim.command('echohl %s'%hlGroupsd['buildConfigNames'])
					vim.command('echon \'%s\''%categoryStr[:posMat[r][c]])

					if dataMat[r][c][posMat[r][c]:] in hlGroupsd:
						categoryColor = hlGroupsd[dataMat[r][c][posMat[r][c]:]]
						vim.command('echohl %s'%categoryColor)
					vim.command('echon \'%s\''%categoryStr[posMat[r][c]:])
				else:
					#vim.command('echon \'%s\''%dataMat[r][c].ljust(maxColWidths[c]))

					itemStr = dataMat[r][c].ljust(maxColWidths[c])
					vim.command('echohl %s'%categoryColor)
					vim.command('echon \'%s\''%itemStr[:posMat[r][c][0]])
					vim.command('echohl %s'%hlGroupsd['shortcut'])
					vim.command('echon \'%s\''%itemStr[posMat[r][c][0]:posMat[r][c][1]])
					vim.command('echohl %s'%hlGroupsd['contents'])
					vim.command('echon \'%s\''%itemStr[posMat[r][c][1]:posMat[r][c][2]])
					vim.command('echohl %s'%hlGroupsd['esc'])
					vim.command('echon \'%s\''%itemStr[posMat[r][c][2]:posMat[r][c][3]])
					vim.command('echohl %s'%hlGroupsd['contents'])
					vim.command('echon \'%s\''%itemStr[posMat[r][c][3]:])

		vim.command('echo \'\'')

else:
	vim.command('echohl %s'%hlGroupsd['labels'])
	vim.command('echo \'No matching patterns for the current window.\'')	

vim.command('echohl None')
EOF

endfun


"""""""""""""""""""""""""""""""""""""""""""""
let &cpo= s:keepcpo
unlet s:keepcpo
