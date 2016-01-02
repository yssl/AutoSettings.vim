# AutoSettings.vim

```
let py_cfg = {}
let py_cfg.localmaps = [
	\[['nnoremap', 'inoremap', 'cnoremap', 'vnoremap'], '<F9>', ':w<CR>:Make; echo \"END:0::\"<CR>'],
\]
let py_cfg.setlocals = [
	\'tabstop=4',
	\'shiftwidth=4',
	\'expandtab',
	\'makeprg=stdbuf\ -i0\ -o0\ -e0\ python\ %',
\]
let g:autoconfig_configs = [
	\['[*.py]', py_cfg],
\]

" or

let g:autoconfig_configs = [
	\['[*.py]',{
		\'localmaps':[
			\[['nnoremap', 'inoremap', 'cnoremap', 'vnoremap'], '<F9>', ':w<CR>:Make; echo \"END:0::\"<CR>']
		\],
		\'setlocals':[
			\'tabstop=4',
			\'shiftwidth=4',
			\'expandtab',
			\'makeprg=stdbuf\ -i0\ -o0\ -e0\ python\ %',
		\]
	\}]
\]
```
