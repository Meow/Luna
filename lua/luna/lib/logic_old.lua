--[[
	Serves to correct logical statements to be
	proper Lua rather than hobo-lua
--]]

local operators = LUA_OPERATORS
local breaks = LUA_SPECIAL

local function extractArgumentStr(str)
	local r, is, so, al = "", false, "", false

	for i = 1, #str do
		local v = str[i]

		if (is) then
			if (v == so) then
				is = false
				so = ""
			end
			r = r..v
			continue
		end

		if (v == "'" or v == '"') then
			is = true
			so = v
			r = r..v
			continue
		end

		if (v == ",") then
			al = true
		end

		if (v == " " and !al) then
			return r, i
		end

		if (v != " ") then
			al = false
		end

		r = r..v
	end

	return r, #str
end

local function patch(str, start, endpos, replacement)
	return (start > 1 and str:sub(1, start - 1) or "")..replacement..str:sub(endpos + 1, str:len())
end

local function getIndentation(str)
	local i = 1
	local v = str:sub(i, i)
	local ret = ""

	while (i <= str:len()) do
		v = str:sub(i, i)

		if (v != " " and v != "\t") then break end

		ret = ret..v

		i = i + 1
	end

	return ret
end

local function searchUntil(str, hit, start, it)
	it = it or 1
	start = start or 1

	local i = start
	local hl = hit:len()

	while (i > 0 and i <= str:len()) do
		if (str:sub(i, i + hl - 1) == hit) then
			return i
		end

		i = i + it
	end

	return i
end

local function searchUntilNot(str, hit, start, it)
	if (!str) then return end

	it = it or 1
	start = start or 1

	local i = start
	local hl = hit:len()

	while (str:sub(i, i + hl - 1) == hit) do
		i = i + it
	end

	return i + 1
end

local function countIndents(str, ind, start, it)
	return math.floor((searchUntilNot(str, ind, start, it) - start - (ind:len() == 1 and 1 or 0)) / ind:len())
end

-- fix the lack of 'then' on functions, as well as possible lack of 'end'
-- Matches the space right after the 'if', goes from there
local function condFix(code, pos, word)
	local endpos = (code:find("\n", pos) - 1) or code:len()
	local block = code:sub(pos, endpos):rtrim():rtrim("\t")

	-- Check the 'then'
	if (block:ends(" and") or block:ends(" or")
		or block:ends("&&") or block:ends("||")) then
		return condFix(code, endpos + 2)
	elseif (!block:ends("then") and !block:ends("end")) then
		code = patch(code, pos, endpos, block.." then")
	end

	endpos = (code:find("\n", pos) - 1) or code:len()

	if (endpos >= code:len()) then
		return code
	end

	-- Check for 'end'
	local closepos, _ = luna.util.FindLogicClosure(code, pos, 2)

	-- Closure not found!
	-- Use indentation to fix it.
	if (word != "elseif" and closepos == -1) then
		local indent = luna.pp:Get("i")
		local initial = searchUntil(code, "\n", pos, -1)
		local indc = countIndents(code, indent, initial + 1)
		local indents = indent:rep(indc)
		local ci = endpos + 1
		local first_gap = -1

		while (true) do
			local lineStart = code:find("\n", ci + 1)
	
			if (!lineStart) then break end

			local lineEnd = code:find("\n", lineStart + 1)

			if (!lineEnd) then break end

			local line = code:sub(lineStart + 1, lineEnd - 1)
			local li = countIndents(line, indent, 1)

			if (li == indc) then
				if (!line:find("elseif") and !line:find("else")) then
					code = patch(code, lineStart, lineStart, "\n"..indents.."end\n")

					break
				end
			elseif (li < indc and line:len() > 1) then
				code = patch(code, lineStart, lineStart, "\n"..indents.."end\n")

				break
			end

			ci = lineEnd - 1
		end
	end

	return code
end

-- fix missing parentheses on function calls and definitions
local function funcFix(code, pos, buf)
	-- First check if we're trying to call a function, this means there shouldn't
	-- be any operators immediately after the name.
	local eol = code:find("\n", pos)

	-- Just wrap the stuff in brackets, it's end of file, no one will notice, hehe.
	if (!eol) then
		return code.."("..(code:len() != pos and code:sub(pos, code:len()) or "")..")"
	end

	local remainder = code:sub(pos, eol - 1):trim():trim("\t")
	local space = remainder:find(" ")
	local fword = remainder

	if (space) then
		fword = remainder:sub(1, space - 1)
	end

	-- Method call. This is DEFINITELY a function call.
	if (buf:find(":") and !remainder:starts("(")) then
		local close = code:find("%c%)\n") or pos
		local block = ""
		local endpos = close - 1

		if (close != pos) then
			block = code:sub(pos, close - 1)
		else
			endpos = pos - 1
		end

		code = patch(code, pos, endpos, "("..block..")")

		return code
	end
	
	if (operators[fword]) then return end
	
	local locals = luna.pp:ExtractLocals(code:sub(1, pos))
	local fc = remainder:sub(1, 1)

	-- Check if it's a function call by checking the pattern.
	if (remainder:len() < 1 or fc:match("[%w_'\"]") and !remainder:starts("then")) then
		-- Fixing a function definition
		if (buf == "function") then
			-- detect a one-liner
			if (!remainder:ends("end") and !remainder:ends(")")) then
				code = patch(code, pos, eol - 1, " "..remainder.."()")
			else
				-- one-liners are trickier
				local def_end = code:find("[%s|%(]", pos + 1)

				if (def_end) then
					local c = code:sub(def_end, def_end)

					if (c != "(") then
						code = patch(code, def_end, def_end, "() ")
					end
				end
			end
		else
			if (!locals.vars[buf]) then
				if (locals.funcs[buf] or isfunction(_G[buf])) then
					code = patch(code, pos, eol - 1, "("..remainder..")")
				end
			end
		end
	end

	return code
end

-- fix do-end blocks being just like table definitions
-- as well as missing 'end' and whatnot
local function doFix(code, pos, buf)

end

-- Implicit return
local function patchReturns(code)
	local fo, fe = code:find("function")

	while (fo) do
		local fc, fce = luna.util.FindLogicClosure(code, fo, 0)
		local block = code:sub(fo, fce)
		local statement = ""
		local istr, iopnr = false, ""

		for i = #block, 1, -1 do
			if (retnd) then break end

			local v = block[i]

			if (istr) then
				if (v == iopnr) then
					istr = false
					iopnr = ""
				end
				statement = statement..v
				continue
			end

			if (v == "'" or v == '"') then
				iopnr = v
				istr = true
				statement = statement..v
				continue
			end

			if (v == "\n" or v:match("%s")) then
				statement = statement:reverse()

				local olen = statement:len()
				local ind = getIndentation(statement)
				statement = statement:trim():trim("\t")

				local bs = searchUntil(block, "\n", i + 1, -1)
				local before = block:sub(bs + 1, i):trim():trim("\t")

				if (!operators[statement] and !before:find("return")) then
					if (statement != "") then
						if (before:find("function ") or !before:find("[%w_]+")) then
							block = patch(block, i + 1, i + olen, ind.."return "..statement)
						else
							block = patch(block, bs + 1, i + olen, ind.."return "..before.." "..statement)
						end
					end

					break
				end

				statement = ""

				continue
			end

			statement = statement..v
		end

		if (!fce) then break end

		code = patch(code, fo, fce, block)
		fo, fe = code:find("function", fe)
	end

	return code
end

luna.pp:AddProcessor("logic", function(code)
	// -> is an alias for method calls
	code = code:gsub("->", ":")

	// ! calls a function with no arguments.
	code = code:gsub("([%w_]+)[!]+([%s\n%)])","%1()%2")

	// ? in function names
	code = code:gsub("([%w_]+)[?]+([%s\n%()])","%1__bool%2")

	local buf = ""
	local instring = false
	local sopen = ""
	local incomment = false
	local prevWord = nil
	local i = 0
	local len = code:len()

	while (i < len) do
		len = code:len()
		i = i + 1

		local v = code:sub(i, i)
		local next = code:sub(i + 1, i + 1)

		if (incomment and v == "\n") then
			incomment = false

			continue
		end

		if (incomment) then continue end

		if (!instring and (v == "'" or v == '"' or (v == "[" and next == "["))) then
			instring = true
			sopen = v
		elseif (instring and (v == sopen or (sopen == "[" and v == "]"))) then
			instring = false
			sopen = ""

			continue
		end

		if (instring or v == "]") then
			continue
		end

		if ((v == "-" and next == "-") or (v == "/" and next == "/")) then
			incomment = true
		end

		if (breaks[v]) then
			-- If we found any if-condition, try to fix it.
			-- Fixers do sanity checks, so we might not bother.
			if (buf == "if" or buf == "elseif") then
				code = condFix(code, i, buf) or code
			-- do the same for {} style do-end blocks.
			elseif (buf == "{") then
				code = doFix(code, i, buf) or code
			elseif (!operators[buf] and buf:match("[%w_]+") and !buf:isnumber() and !buf:isbool()) then
				code = funcFix(code, i, buf) or code
			end

			buf = ""

			continue
		end

		buf = tostring(buf)..tostring(v)
	end

	if (buf != "" and !operators[buf] and buf:match("[%w_]+")) then
		code = funcFix(code, i, buf) or code
	end

	code = patchReturns(code)

	return code
end)