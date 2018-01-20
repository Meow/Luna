--[[
	Now, before you progress any further, I just want to say
	that the pre-processor is some pretty bad code. It's not
	written with readability or any plans to change it in mind.
--]]

-- Globals used during processing
_SCOPE = {}
_GLOBALS = {}
_LOCALS = {}
_CONTEXTS = {}
CURRENT_PATH = "unknown"

CONTEXT_OPENERS = {
	["function"] = true,
	["if"] = true,
	["do"] = true
}

CONTEXT_CLOSERS = {
	["end"] = true
}

LUA_OPERATORS = {
	["if"] = true,
	["elseif"] = true,
	["else"] = true,
	["and"] = true,
	["or"] = true,
	["local"] = true,
	["end"] = true,
	["while"] = true,
	["for"] = true,
	["do"] = true,
	["return"] = true,
	["break"] = true,
	["continue"] = true,
	["then"] = true,
	["true"] = true,
	["false"] = true,
	["nil"] = true,
	["function"] = true
}

LUA_LITERALS = {
	["nil"] = true,
	["false"] = true,
	["true"] = true
}

LUA_OP_SYMBOLS = {
	["="] = true,
	["+"] = true,
	["-"] = true,
	["+="] = true,
	["-="] = true,
	[">"] = true,
	["<"] = true,
	[">="] = true,
	["<="] = true,
	["/"] = true,
	["*"] = true,
	["%"] = true,
	["^"] = true,
	["&"] = true,
	["|"] = true
}

LUA_EXPRESSION_WHITELIST = {
	["=="] = true,
	["+"] = true,
	["-"] = true,
	[">"] = true,
	["<"] = true,
	[">="] = true,
	["<="] = true,
	["/"] = true,
	["*"] = true,
	["%"] = true,
	["^"] = true,
	["&"] = true,
	["|"] = true
}

LUA_SPECIAL = {
	["("] = true,
	[")"] = true,
	[" "] = true,
	[","] = true,
	["\t"] = true,
	["\n"] = true,
	["["] = true,
	["]"] = true
}

local processors = {}

-- returnBuffer is what is returned back to C++.
local returnBuffer = ""
-- words = table of all words that were processed
-- word = current word
-- v = current letter
-- buf = unfinished word
-- line = current line
-- curLine = current line number
local words, word, v, buf, line, curLine = {}, "", "", "", "", 0
-- difference between the sizes of the original code and pre-processed thing.
local offset = 0
-- Original, unmodified code
local origCode = ""
-- Indentation character.
local indent = ""
-- Current line's indentation count
local lineIndent = 0
local errors = {}
local parse_error_critical = false
local nullfunc = function() end

-- Universal accessor for locals. Ugly.
function luna.pp:Get(what)
	what = what:lower()

	if (what == "words") then
		return words
	elseif (what == "word") then
		return word
	elseif (what == "v") then
		return v
	elseif (what == "buf") then
		return buf
	elseif (what == "line") then
		return line
	elseif (what == "curline") then
		return curLine
	elseif (what == "returnbuffer") then
		return returnBuffer
	elseif (what == "origcode") then
		return origCode
	elseif (what == "offset") then
		return offset
	elseif (what == "indent" or what == "i") then
		return indent
	elseif (what == "lineindent" or what == "li") then
		return lineIndent
	end
end

function luna.pp:PatchStr(str, start, endpos, replacement)
	return (start > 1 and str:sub(1, start - 1) or "")..replacement..str:sub(endpos + 1, str:len())
end

function luna.pp:AddProcessor(uniqueID, code)
	table.insert(processors, {uniqueID, code})
end

function luna.pp:RemoveProcessor(uniqueID)
	for k, v in ipairs(processors) do
		if (v[1] == uniqueID) then
			table.remove(k)

			break
		end
	end
end

function luna.pp:Hit(str, what, start, negate)
	local i = start or 1
	local l = str:len()

	if (!istable(what)) then what = {what} end

	while (true) do
		if (i > l) then break end

		local slug = str:sub(i, i)

		for k, v in ipairs(what) do
			if (slug:match(v)) then
				if (!negate) then
					return i, v
				end
			elseif (negate) then
				return i, v
			end
		end

		i = i + 1
	end
end

function luna.pp:Next(str, pos)
	return self:Hit(str, "%s", pos, true)
end

function luna.pp:WordEnd(str, pos)
	local we = self:Hit(str, "%s", pos)

	return isnumber(we) and we - 1
end

-- stupidly extract locals from string
-- no checks for context!!!
function luna.pp:ExtractLocals(str)
	-- we separate them to variables and functions
	-- so that the preprocessor knows where to put the stupid brackets...
	local ret = {
		vars = {},
		funcs = {}
	}

	-- find w/e starts with local tag
	local s, e = str:find("local")

	while (s) do
		local wst = self:Next(str, e + 1)
		local wnd = self:WordEnd(str, wst)

		if (!wst or !wnd) then
			ErrorNoHalt("Exception thrown while extracting locals!\n")

			break
		end

		local slug = str:sub(wst, wnd)

		-- 'local function'
		if (slug == "function") then
			local nst = self:Next(str, wnd + 1)
			local nnd = self:WordEnd(nst, nst)
			local w = str:sub(nst, nnd)

			ret.funcs[w] = true
		else
			local varstrt = self:Hit(str, {"%s", "="}, wnd + 1, true)
			local varnd = self:Hit(str, {"%s", "%(", "{"}, varstrt) - 1
			local val = str:sub(varstrt, varnd)

			if (val == "function") then
				ret.funcs[slug] = true
			else
				ret.vars[slug] = true
			end
		end

		s, e = str:find("local", e)
	end

	-- then find function definitions, it doesn't really matter if we check for local function or just function
	local s, e = str:find("function")

	while (s) do
		local wst = self:Next(str, e + 1)
		local wnd = self:Hit(str, {"%s", "%(", "\n"}, wst) - 1

		if (wst and wnd) then
			local slug = str:sub(wst, wnd)

			ret.funcs[slug] = true
		end

		s, e = str:find("function", e)
	end

	return ret
end

function luna.pp:GetContext(pos, context)
	local lx, ly = 0, 0
	local littlest = nil

	for k, v in ipairs(context or _CONTEXTS) do
		if (pos >= v[2] and pos <= v[3]) then
			if (lx == 0) then
				lx = v[2]
				ly = v[3]
				littlest = v
			end

			if (ly - lx > v[3] - v[2]) then
				lx = v[2]
				ly = v[3]
				littlest = v
			end
		end
	end

	return littlest
end

-- Pass an entire file or code block to this
function luna.pp:ReadGlobalLocals(str)

end

-- Pass only a single context to this
-- (a block between 'if', 'function' or 'do' and an 'end')
function luna.pp:ReadContextLocals(str)
	-- basically run the previous function on the context
end

-- Extract all context blocks from any text.
function luna.pp:GetContexts(str)
	local len = 0
	local lines = string.explode("\n", str)
	local ret = {}

	for k, v in ipairs(lines) do
		local t = v:trim():trim("\t")

		-- one-liners
		if ((t:starts("function") or t:find("do")) and t:ends("end")) then
			table.insert(ret, {v, len + 1, len + v:len()})
		elseif (t:starts("function") or t:ends("do") or t:starts("for") or t:starts("while")) then -- function or do-end
			local indent = v:match("([%s]*)[%w_]")
			local closure, closure_e = str:find("\n"..indent.."end", len)

			if (closure_e) then
				table.insert(ret, {str:sub(len + 1, closure_e), len + 1, closure_e})
			end
		elseif ((t:starts("if") or t:starts("else")) and t:ends("end")) then -- logical one-liners
			table.insert(ret, {v, len + 1, len + v:len()})
		elseif (t:starts("if") or t:starts("elseif") or t:starts("else")) then -- logic
			local indent = v:match("([%s]*)[%w_]")

			-- Because at this stage some stuff might not have proper 'end' we
			-- need to use indentation to find out where it's closure might be.
			local closure, closure_e, ind = str:find("\n([%s]*)[%w_'%p\"]+[%s\n%(]", len + 1)

			while (closure and #indent < #ind) do
				closure, closure_e, ind = str:find("\n([%s]*)[%w_'%p\"]+[%s\n%(]", closure_e)
			end

			if (closure_e and #indent >= #ind) then
				table.insert(ret, {str:sub(len + 1, closure_e), len + 1, closure_e})
			end
		end

		len = len + v:len() + 1 -- Account for newline
	end

	return ret
end

function luna.pp:OffsetContexts(pos, diff)
	for k, v in ipairs(_CONTEXTS) do
		if (v[2] > pos) then
			_CONTEXTS[k][2] = v[2] + diff
			_CONTEXTS[k][3] = v[3] + diff
		end
	end
end

ERROR_WARNING = 0
ERROR_CRITICAL = 1
ERROR_DEPRECATION = 2
ERROR_UNCLEAR = 3

function parser_error(msg, offset, type)
	local err = {
		msg = msg,
		offset = offset,
		type = type
	}

	table.insert(errors, err)

	if (hook.Run("luna_compilation_error", err) == false or type == ERROR_CRITICAL) then
		parse_error_critical = true
	end
end

hook.Add("luna_compiler_logic_fixed", "luna_read_globals", function(obj)
	local code = obj.code
	-- First read the functions
	local s, e = code:find("function")
	local contexts = {check = function(self, p)
		for k, v in ipairs(self) do
			if (p >= v[1] and p <= v[2]) then
				return _GLOBALS[v[3]]
			end
		end

		return false
	end}

	while (s) do
		local context_end, real_end = luna.util.FindLogicClosure(code, e, 1)

		if (context_end) then
			local info = {
				type = "function",
				is_func = true,
				luna = true,
				context_start = s,
				context_end = real_end,
				path = CURRENT_PATH,
				splattable = false,
				yieldable = false
			}

			local block = code:sub(s, context_end)
			local st, ed, fn = block:find("function%s-([^%(%s]+)")

			info.name = fn

			-- Anonymous function
			if (!st) then
				s, e = code:find("function", real_end)
				continue
			end

			if (block:sub(ed + 1, block:find("\n", ed)):find("[%(%)]")) then
				info.args_str = read_arguments(block, ed + 1)
				info.args_amt = #info.args_str:split(",")

				if (info.args_str:find("%*[%w_%.:]")) then
					info.splattable = true
				end
			end

			if (block:find("[%s\n]yield")) then
				info.yieldable = true
			end

			hook.Run("luna_adjust_function_info", info, block, code)

			table.insert(contexts, {s, real_end, fn})

			_GLOBALS[fn] = info
		else
			parser_error("'end' expected to close function!", s, ERROR_CRITICAL)
			break
		end

		s, e = code:find("function", real_end)
	end

	local s, e, name = code:find("\n%s*([%w_%.]+)%s*=")

	while (s) do
		if (!contexts:check(s)) then
			local info = {
				type = "variable",
				name = name,
				def_start = s,
				def_end = e,
				path = CURRENT_PATH,
				luna = true,
				is_func = false
			}

			local remain = code:sub(e, code:find("\n", e))
			local func_start, func_end = remain:find("function")

			if (func_start) then
				info.type = "function"
				info.is_func = true
				
				local context_end, real_end = luna.util.FindLogicClosure(code, e, 0)

				if (context_end) then
					local block = code:sub(s, real_end)
		
					info.context_start = s
					info.context_end = real_end

					if (block:sub(func_end + 1, block:find("\n", func_end)):find("[%(%)]")) then
						info.args_str = read_arguments(block, func_end + 1)
						info.args_amt = #info.args_str:split(",")

						if (info.args_str:find("%*[%w_%.:]")) then
							info.splattable = true
						end
					end

					if (block:find("[%s\n]yield")) then
						info.yieldable = true
					end

					hook.Run("luna_adjust_function_info", info, block, code)

					table.insert(contexts, {s, real_end, name})
				else
					parser_error("'end' expected to close function!", func_start, ERROR_CRITICAL)
					break
				end
			end

			_GLOBALS[name] = info
		end

		s, e, name = code:find("\n%s*([%w_%.]+)%s*=", e)
	end

	hook.Run("luna_globals_info_gathered", obj)
end)

include("helpers.lua")
include("lib/minifier.lua")
include("lib/macros.lua")
include("lib/define.lua")
include("lib/pretty_logic.lua")
include("lib/loops.lua")
include("lib/special_funcs.lua")
include("lib/default_args.lua")
include("lib/namespaces.lua")
include("lib/ops.lua")
include("lib/splat_yield.lua")
include("lib/logic.lua")
include("lib/str_interp.lua")

local function analyzeIndentation(code)
	local lid = ""
	local ldc = 0
	local idcs = {}
	local sidc = false
	local lidnt = 0

	for i = 1, code:len() do
		local v = code:sub(i, i)

		-- it's newline, time to analyze the indentations
		if (v == "\n") then
			sidc = true

			continue
		end

		if (sidc) then
			-- tab or a space
			if (v == "\t" or v == " ") then
				-- generic 'count the character'
				if (lid == "") then
					lid = v
					ldc = ldc + 1
				elseif (v == lid) then
					ldc = ldc + 1
				end
			else
				if (ldc and lidnt and ldc > lidnt and ldc % lidnt == 0) then
					ldc = ldc / lidnt
				end

				-- we've hit something other than indent character
				if (lid != "") then
					table.insert(idcs, {lid, ldc})
				end

				lidnt = ldc

				-- reset
				lid, ldc = "", 0
				sidc = false
			end
		end
	end

	local comm = {} -- how many spaces if it's spaces, lowest val is picked
	local hits = {} -- spaces or tabs

	-- build the above tables
	for k, v in ipairs(idcs) do
		local a, b = v[1], v[2]
	
		hits[a] = hits[a] or 0
		comm[a] = comm[a] or b

		hits[a] = hits[a] + 1

		if (comm[a] > b) then
			comm[a] = b
		end
	end

	-- pick winning key, based on how many times in the document it's encountered
	local winner_winner = 0
	local chicken_dinner = ""

	for k, v in pairs(hits) do
		if (v > winner_winner) then
			winner_winner = v
			chicken_dinner = k
		end
	end

	-- if we've hit an error of some sort, just return the good ole tab as a fail safe.
	if (!comm[chicken_dinner]) then
		return "\t"
	end

	-- And now actually build the sequence and return that
	local r = ""

	for i = 1, comm[chicken_dinner] do
		r = r..chicken_dinner
	end

	return r
end

local function get_all_strings(code)
	local ret = {}

	table.Add(ret, code:find_all("('[^']+')"))
	table.Add(ret, code:find_all("(\"[^\"]+\")"))
	table.Add(ret, code:find_all("(%[%[[^%]%]]+%]%])"))

	return ret
end

local function strip_comments(code)
	code = code:gsub("/%*[^%*%/]+*/", "")
	code = code:gsub("%-%-%[%[[^%]]+%]%]", "")
	code = code:gsub("//[^\n]+", "")
	code = code:gsub("%-%-[^\n]+", "")

	return code
end

local DEBUG = true

local function minify(code)
	if (!DEBUG) then
		return luna.minifier:Minify(code, DEBUG)
	end
end

local function debug_print(msg)
	if (DEBUG) then
		print(msg)
	end
end

hook.Add("Lua_Preprocess", "Luna_Preprocessor", function(code, path)
	if (!path:find(".lun")) then
		return code
	end

	CURRENT_PATH = path

	-- Print before starting the benchmark so that we don't
	-- get screwed by stdio.
	debug_print("Pre-Processing Luna source...")

	local start_time = CurTime()

	-- Have a copy of the original code ready in case we need it.
	returnBuffer = code

	-- Comments should be stripped before the compilation
	-- so that we can simply not bother about them...
	returnBuffer = strip_comments(returnBuffer) or returnBuffer

	-- Reset in string buffer cache so that it returns the correct results.
	_instr_cache = {}

	-- Add an extra newline to the end of the code so that the parser
	-- can simply not worry about it.
	returnBuffer = returnBuffer.."\n"

	indent = analyzeIndentation(returnBuffer)

	debug_print("Indentation identified as: "..(indent != "\t" and indent:len().." space"..(indent:len() > 1 and "s" or "") or "a tab"))
	debug_print("Running processors...")

	for k, v in ipairs(processors) do
		-- Error. Cannot continue.
		if (parse_error_critical) then
			local err = errors[#errors]

			ErrorNoHalt("[ERROR] Critical compilation error occured!\n")
			ErrorNoHalt(tostring(err.msg).."\n")

			return code
		end

		debug_print("Running processor: "..v[1])

		local success, value = pcall(v[2], returnBuffer)

		if (success) then
			returnBuffer = value or returnBuffer
		else
			parser_error(value, -1, ERROR_CRITICAL)
		end
	end

	-- Alright we can minify this shit now...
	returnBuffer = minify(returnBuffer) or returnBuffer

	debug_print("Finished processing in "..math.round(CurTime() - start_time, 4).."ms.")
	debug_print(returnBuffer)

	return returnBuffer
end)