local M = {}

local config = {
	enabled = true,
	max_depth = 1,
	min_window_height = 10,
	clobber_priority = 10,
	gutter_char_open = "{",
	gutter_char_close = "}",
}

-- State
local ns_id = vim.api.nvim_create_namespace("gutter_context")
local context_cache = {}
local last_cursor_line = 0

local function has_treesitter()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return false
	end

	local lang = parsers.get_buf_lang()
	if not lang then
		return false
	end

	return parsers.has_parser(lang)
end

local function get_root()
	local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
	if not ok then
		return nil
	end

	local parser = vim.treesitter.get_parser()
	if not parser then
		return nil
	end

	local tree = parser:parse()[1]
	return tree and tree:root()
end

local function should_include_node(node)
	local node_type = node:type()

	-- Common context-worthy node types across languages
	local context_types = {
		-- Functions and methods
		"function_declaration",
		"function_definition",
		"method_declaration",
		"method_definition",
		"function",
		"arrow_function",
		"function_item",

		-- Classes and structures
		"class_declaration",
		"class_definition",
		"struct_declaration",
		"struct_definition",
		"interface_declaration",
		"trait_declaration",
		"impl_item",

		-- Control flow
		"if_statement",
		"for_statement",
		"while_statement",
		"loop_statement",
		"match_statement",
		"switch_statement",
		"try_statement",

		-- Blocks and scopes
		"block",
		"compound_statement",
		"statement_block",

		-- Modules and namespaces
		"module",
		"namespace",
		"package_declaration",

		-- Language specific
		"chunk", -- Lua
		"source_file",
		"program", -- General
	}

	for _, type in ipairs(context_types) do
		if node_type == type then
			return true
		end
	end

	return false
end

local function get_context_nodes(line)
	local root = get_root()
	if not root then
		return {}
	end

	local contexts = {}
	local current_node = root:descendant_for_range(line, 0, line, 0)

	if not current_node then
		return {}
	end

	-- Walk up the tree to find context nodes
	local node = current_node
	local depth = 0

	while node and depth < config.max_depth do
		if should_include_node(node) then
			local start_row, start_col, end_row, end_col = node:range()

			-- Only include if the context starts before our line
			if start_row < line then
				table.insert(contexts, {
					node = node,
					start_line = start_row + 1, -- Convert to 1-based
					end_line = end_row + 1, -- Convert to 1-based
					depth = depth,
				})
				depth = depth + 1
			end
		end
		node = node:parent()
	end

	-- Reverse to get outermost context first
	local result = {}
	for i = #contexts, 1, -1 do
		table.insert(result, contexts[i])
	end

	return result
end

local function clear_gutter_signs(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

local function place_gutter_signs(bufnr, contexts, current_line)
	clear_gutter_signs(bufnr)

	if not contexts or #contexts == 0 then
		return
	end

	-- avoid duplicates
	local signed_lines = {}

	for i, context in ipairs(contexts) do
		local start_line = context.start_line
		local end_line = context.end_line

		if start_line ~= current_line and not signed_lines[start_line] then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_line - 1, 0, {
				sign_text = config.gutter_char_open,
				sign_hl_group = "LineNr",
				priority = config.clobber_priority + i,
			})
			signed_lines[start_line] = true
		end

		if end_line <= vim.api.nvim_buf_line_count(bufnr) and not signed_lines[end_line] then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, end_line - 1, 0, {
				sign_text = config.gutter_char_close,
				sign_hl_group = "LineNr",
				priority = config.clobber_priority + i,
			})
			signed_lines[end_line] = true
		end
	end
end

local function update_context()
	if not config.enabled then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local winnr = vim.api.nvim_get_current_win()

	if vim.api.nvim_win_get_height(winnr) < config.min_window_height then
		clear_gutter_signs(bufnr)
		return
	end

	if not has_treesitter() then
		clear_gutter_signs(bufnr)
		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(winnr)[1]

	-- Avoid unnecessary updates
	if cursor_line == last_cursor_line and context_cache[bufnr] then
		return
	end

	last_cursor_line = cursor_line
	local contexts = get_context_nodes(cursor_line - 1) -- Convert to 0-based
	context_cache[bufnr] = contexts
	place_gutter_signs(bufnr, contexts, cursor_line)
end

local function setup_autocommands()
	local group = vim.api.nvim_create_augroup("GutterContext", { clear = true })

	vim.api.nvim_create_autocmd({
		"CursorMoved",
		"CursorMovedI",
		"BufEnter",
		"WinEnter",
	}, {
		group = group,
		callback = function()
			vim.schedule(update_context)
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function(args)
			clear_gutter_signs(args.buf)
			context_cache[args.buf] = nil
		end,
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(args)
			context_cache[args.buf] = nil
		end,
	})
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	setup_autocommands()
end

function M.enable()
	config.enabled = true
	update_context()
end

function M.disable()
	config.enabled = false
	local bufnr = vim.api.nvim_get_current_buf()
	clear_gutter_signs(bufnr)
end

function M.toggle()
	if config.enabled then
		M.disable()
	else
		M.enable()
	end
end

vim.api.nvim_create_user_command("GutterContextEnable", M.enable, {})
vim.api.nvim_create_user_command("GutterContextDisable", M.disable, {})
vim.api.nvim_create_user_command("GutterContextToggle", M.toggle, {})

return M
