-- Module containing general-purpose functions

local Path = require 'plenary.path'

local utils = {}

---@return string|osdate date Today's date in "yyyy Jan dd" format
utils.date = function()
	return os.date('%Y %b %d')
end

-- Read the template file with the extension `ext` into the current buffer and
-- set the cursor's position to `curpos`, which uses (1,0) indexing
-- |api-indexing|. By default, template files are searched for in
-- `stdpath("config")/templates`; set `vim.g.template_path` to change this
-- search path.
---@param ext string Extension of template file, e.g., ".c" or ".mk"
---@param curpos number[] (row, col) tuple indicating the new position
utils.read_template_file = function(ext, curpos)
	local filename = 'template' .. ext
	local path = vim.g.template_path
		and Path:new(vim.g.template_path)
		or Path:new(vim.fn.stdpath('config'), 'templates')
	path = path:joinpath(filename)

	vim.cmd.read(path.filename)
	vim.api.nvim_buf_set_lines(0, 0, 1, false, {})
	vim.api.nvim_win_set_cursor(0, curpos)
end

-- Sets the values for the "ifndef" guard in the current file based on the
-- file's name and current date (yyyymmdd).
utils.set_header_macros = function()
	local macro_name = ' ' .. string.gsub(string.upper(vim.fn.expand('%:t')),
					'%.', '_' .. os.date('%Y%m%d') .. '_')
	vim.api.nvim_buf_set_lines(0, 0, 1, false,
		{ vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] .. macro_name })
	vim.api.nvim_buf_set_lines(0, 1, 2, false,
		{ vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] .. macro_name })
	vim.api.nvim_buf_set_lines(0, -2, -1, false,
		{ vim.api.nvim_buf_get_lines(0, -2, -1, false)[1] .. ' //' .. macro_name })
end

-- Deletes starting and ending blank lines in the current buffer. For example,
-- for the following buffer,
-- ```
--1
--2 A line containing non-space characters.
--3
--4 Another line.
--5
--6
--7
-- ```
-- `utils.trim_peripheral_blank_lines()` will delete four lines: one at the
-- start (line 1) and three at the end (lines 5, 6, and 7).
utils.trim_peripheral_blank_lines = function()
	local curbuf = vim.fn.bufnr()
	local total_lines = vim.fn.line('$')

	local n_starting_blank_lines = 0
	for i = 1, total_lines do
		if string.match(vim.fn.getline(i), '%S') then
			break
		end
		n_starting_blank_lines = n_starting_blank_lines + 1
	end

	local n_ending_blank_lines = 0
	if n_starting_blank_lines ~= total_lines then
		for i = total_lines, 1, -1 do
			if string.match(vim.fn.getline(i), '%S') then
				break
			end
			n_ending_blank_lines = n_ending_blank_lines + 1
		end
	end

	-- Delete ending lines first; doing the reverse messes the line count
	-- for the ending lines.
	vim.fn.deletebufline(curbuf, total_lines - n_ending_blank_lines + 1, total_lines)
	vim.fn.deletebufline(curbuf, 1, n_starting_blank_lines)

	local n_lines_deleted = n_starting_blank_lines + n_ending_blank_lines

	if n_lines_deleted == total_lines then
		vim.cmd.echomsg '"--No lines in buffer--"'
	elseif n_lines_deleted > vim.o.report then
		vim.cmd.echomsg((n_lines_deleted == 1)
			and n_lines_deleted .. ' "line less"'
			or n_lines_deleted .. ' "fewer lines"')
	end
end

-- Deletes trailing whitespace in the current buffer.
utils.trim_trailing_whitespace = function()
	local save_view = vim.fn.winsaveview()
	local save_search = vim.fn.getreg('/')
	vim.cmd([[%substitute/\v\s+$//e]])
	vim.fn.winrestview(save_view)
	vim.fn.setreg('/', save_search)
end

-- Updates the date found after the first occurrence of the string
-- "Last change:" in the first 20 lines of the current file. The format of the
-- new date may be specified (see `strftime()` for valid formats). If no format
-- is given, the date returned by `utils.date()` is used.
---@param format? string Format of the new date
utils.update_last_change = function(format)
	local pat = 'Last [Cc]hange:'
	local limit = 20
	if vim.fn.line('$') < limit then
		limit = vim.fn.line('$')
	end
	for i = 1, limit do
		local line = vim.fn.getline(i)
		if string.match(line, pat) then
			local c = ''
			if not string.match(line, pat .. '%s') then
				c = '\t'
			end
			local updated_line = string.gsub(line, '(' .. pat .. ')%s*.*$',
				'%1' .. c .. (format and os.date(format) or utils.date()))
			vim.fn.setline(i, updated_line)
			break
		end
	end
end

return utils
