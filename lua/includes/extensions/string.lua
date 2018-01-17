util = util or {}

local string = string
local math = math

--[[---------------------------------------------------------
	Name: string.totable(string)
-----------------------------------------------------------]]
function string.totable (str)
	local tbl = {}

	for i = 1, string.len(str) do
		tbl[i] = string.sub(str, i, i)
	end

	return tbl
end

--[[---------------------------------------------------------
   Name: string.js_safe(string)
   Desc: Takes a string and escapes it for insertion in to a JavaScript string
-----------------------------------------------------------]]
local javascript_escape_replacements = {
	["\\"] = "\\\\",
	["\0"] = "\\x00" ,
	["\b"] = "\\b" ,
	["\t"] = "\\t" ,
	["\n"] = "\\n" ,
	["\v"] = "\\v" ,
	["\f"] = "\\f" ,
	["\r"] = "\\r" ,
	["\""] = "\\\"",
	["\'"] = "\\\'"
}

function string.js_safe(str)
	str = str:gsub(".", javascript_escape_replacements)

	-- U+2028 and U+2029 are treated as line separators in JavaScript, handle separately as they aren't single-byte
	str = str:gsub("\226\128\168", "\\\226\128\168")
	str = str:gsub("\226\128\169", "\\\226\128\169")

	return str
end

--[[---------------------------------------------------------
   Name: string.pattern_safe(string)
   Desc: Takes a string and escapes it for insertion in to a Lua pattern
-----------------------------------------------------------]]
local pattern_escape_replacements = {
	["("] = "%(",
	[")"] = "%)",
	["."] = "%.",
	["%"] = "%%",
	["+"] = "%+",
	["-"] = "%-",
	["*"] = "%*",
	["?"] = "%?",
	["["] = "%[",
	["]"] = "%]",
	["^"] = "%^",
	["$"] = "%$",
	["\0"] = "%z"
}

function string.pattern_safe(str)
	return (str:gsub(".", pattern_escape_replacements))
end

--[[---------------------------------------------------------
   Name: explode(seperator ,string)
   Desc: Takes a string and turns it into a table
   Usage: string.explode(" ", "Seperate this string")
-----------------------------------------------------------]]
local totable = string.totable
local string_sub = string.sub
local string_find = string.find
local string_len = string.len
function string.explode(separator, str, withpattern)
	if (separator == "") then return totable(str) end
	if (withpattern == nil) then withpattern = false end

	local ret = {}
	local current_pos = 1

	for i = 1, string_len(str) do
		local start_pos, end_pos = string_find(str, separator, current_pos, !withpattern)

		if (!start_pos) then break end

		ret[i] = string_sub(str, current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end

	ret[#ret + 1] = string_sub(str, current_pos)

	return ret
end

function string.split(str, delimiter)
	return string.explode(delimiter, str)
end

--[[---------------------------------------------------------
	Name: implode(seperator, Table)
	Desc: Takes a table and turns it into a string
	Usage: string.implode(" ", { "This", "Is", "A", "Table" })
-----------------------------------------------------------]]
function string.implode(seperator, Table) return
	table.concat(Table, seperator)
end

--[[---------------------------------------------------------
	Name: ext(path)
	Desc: Returns extension from path
	Usage: string.ext("garrysmod/lua/modules/string.lua")
-----------------------------------------------------------]]
function string.ext(path)
	return path:match("%.([^%.]+)$")
end

--[[---------------------------------------------------------
	Name: noext(path)
-----------------------------------------------------------]]
function string.noext(path)
	local i = path:match(".+()%.%w+$")
	if (i) then return path:sub(1, i - 1) end
	return path
end

--[[---------------------------------------------------------
	Name: path(path)
	Desc: Returns path from filepath
	Usage: string.path("garrysmod/lua/modules/string.lua")
-----------------------------------------------------------]]
function string.path(path)
	return path:match("^(.*[/\\])[^/\\]-$") or ""
end

--[[---------------------------------------------------------
	Name: file(path)
	Desc: Returns file with extension from path
	Usage: string.file("garrysmod/lua/modules/string.lua")
-----------------------------------------------------------]]
function string.file(path)
	if (!path:find("\\") and !path:find("/")) then return path end 
	return path:match("[\\/]([^/\\]+)$") or ""
end

--[[-----------------------------------------------------------------
	Name: format_time(TimeInSeconds, Format)
	Desc: Given a time in seconds, returns formatted time
			If 'Format' is not specified the function returns a table
			conatining values for hours, mins, secs, ms

   Examples: string.format_time(123.456, "%02i:%02i:%02i")	==> "02:03:45"
			 string.format_time(123.456, "%02i:%02i")		==> "02:03"
			 string.format_time(123.456, "%2i:%02i")			==> " 2:03"
			 string.format_time(123.456)					==> { h = 0, m = 2, s = 3, ms = 45 }
-------------------------------------------------------------------]]
function string.format_time(seconds, format)
	if (not seconds) then seconds = 0 end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds / 60) % 60)
	local millisecs = (seconds - math.floor(seconds)) * 100
	seconds = math.floor(seconds % 60)

	if (format) then
		return string.format(format, minutes, seconds, millisecs)
	else
		return { h = hours, m = minutes, s = seconds, ms = millisecs }
	end
end

local function pluralizeString(str, quantity)
	return str .. ((quantity ~= 1) and "s" or "")
end

function string.nice_time(seconds)
	if (seconds == nil) then return "a few seconds" end

	if (seconds < 60) then
		local t = math.floor(seconds)
		return t .. pluralizeString(" second", t)
	end

	if (seconds < 60 * 60) then
		local t = math.floor(seconds / 60)
		return t .. pluralizeString(" minute", t)
	end

	if (seconds < 60 * 60 * 24) then
		local t = math.floor(seconds / (60 * 60))
		return t .. pluralizeString(" hour", t)
	end

	if (seconds < 60 * 60 * 24 * 7) then
		local t = math.floor(seconds / (60 * 60 * 24))
		return t .. pluralizeString(" day", t)
	end

	if (seconds < 60 * 60 * 24 * 365) then
		local t = math.floor(seconds / (60 * 60 * 24 * 7))
		return t .. pluralizeString(" week", t)
	end

	local t = math.floor(seconds / (60 * 60 * 24 * 365))
	return t .. pluralizeString(" year", t)
end

function string.Left(str, num) return string.sub(str, 1, num) end
function string.Right(str, num) return string.sub(str, -num) end

function string.Replace(str, tofind, toreplace)
	local tbl = string.explode(tofind, str)
	if (tbl[1]) then return table.concat(tbl, toreplace) end
	return str
end

--[[---------------------------------------------------------
	Name: trim(s)
	Desc: Removes leading and trailing spaces from a string.
			Optionally pass char to trim that character from the ends instead of space
-----------------------------------------------------------]]
function string.trim(s, char)
	if (char) then char = char:pattern_safe() else char = "%s" end
	return string.match(s, "^" .. char .. "*(.-)" .. char .. "*$") or s
end

--[[---------------------------------------------------------
	Name: rtrim(s)
	Desc: Removes trailing spaces from a string.
			Optionally pass char to trim that character from the ends instead of space
-----------------------------------------------------------]]
function string.rtrim(s, char)
	if (char) then char = char:pattern_safe() else char = "%s" end
	return string.match(s, "^(.-)" .. char .. "*$") or s
end

--[[---------------------------------------------------------
	Name: trimLeft(s)
	Desc: Removes leading spaces from a string.
			Optionally pass char to trim that character from the ends instead of space
-----------------------------------------------------------]]
function string.ltrim(s, char)
	if (char) then char = char:pattern_safe() else char = "%s" end
	return string.match(s, "^" .. char .. "*(.+)$") or s
end

function string.size(size)
	size = tonumber(size)

	if (size <= 0) then return "0" end
	if (size < 1024) then return size .. " Bytes" end
	if (size < 1024 * 1024) then return math.round(size / 1024, 2) .. " KB" end
	if (size < 1024 * 1024 * 1024) then return math.round(size / (1024 * 1024), 2) .. " MB" end

	return math.round(size / (1024 * 1024 * 1024), 2) .. " GB"
end

-- Note: These use Lua index numbering, not what you'd expect
-- ie they start from 1, not 0.

function string.setchar(s, k, v)
	local start = s:sub(0, k-1)
	local send = s:sub(k+1)

	return start .. v .. send
end

function string.getchar(s, k)
	return s:sub(k, k)
end

local meta = getmetatable("")

function meta:__index(key)
	local val = string[key]
	if (val) then
		return val
	elseif (tonumber(key)) then
		return self:sub(key, key)
	else
		error("attempt to index a string value with bad key ('" .. tostring(key) .. "' is not part of the string library)", 2)
	end
end

function meta:__add(right)
	return self..right
end

function string.starts(String, Start)
   return string.sub(String, 1, string.len (Start)) == Start
end

function string.ends(String, End)
   return End == "" or string.sub(String, -string.len(End)) == End
end

function string.comma(number)
	local number, k = tostring(number), nil

	while true do
		number, k = string.gsub(number, "^(-?%d+)(%d%d%d)", "%1,%2")
		if (k == 0) then break end
	end

	return number
end

do
	local vowels = {
		["a"] = true,
		["e"] = true,
		["o"] = true,
		["i"] = true,
		["u"] = true,
		["y"] = true,
	}

	-- A function to check whether character is vowel or not.
	function util.IsVowel(char)
		if (!isstring(char)) then return false end

		return vowels[char:lower()]
	end
end

-- A function to remove a substring from the end of the string.
function string.RemoveTextFromEnd(str, strNeedle, bAllOccurences)
	if (!strNeedle or strNeedle == "") then
		return str
	end

	if (str:ends(strNeedle)) then
		if (bAllOccurences) then
			while (str:ends(strNeedle)) do
				str = str:RemoveTextFromEnd(strNeedle)
			end

			return str
		end

		return str:sub(1, str:len() - strNeedle:len())
	else
		return str
	end
end

-- A function to remove a substring from the beginning of the string.
function string.RemoveTextFromStart(str, strNeedle, bAllOccurences)
	if (!strNeedle or strNeedle == "") then
		return str
	end

	if (str:starts(strNeedle)) then
		if (bAllOccurences) then
			while (str:starts(strNeedle)) do
				str = str:RemoveTextFromStart(strNeedle)
			end

			return str
		end

		return str:sub(strNeedle:len() + 1, str:len())
	else
		return str
	end
end

-- A function to check whether the string is full uppercase or not.
function string.IsUppercase(str)
	return string.upper(str) == str
end

-- A function to check whether the string is full lowercase or not.
function string.IsLowercase(str)
	return string.lower(str) == str
end

-- A function to find all occurences of a substring in a string.
function string.find_all(str, pattern)
	if (!str or !pattern) then return end

	local hits = {}
	local lastPos = 1

	while (true) do
		local startPos, endPos = string.find(str, pattern, lastPos)

		if (!startPos) then
			break
		end

		table.insert(hits, {string.sub(str, startPos, endPos), startPos, endPos})

		lastPos = endPos + 1
	end

	return hits
end

do
	-- ID's should not have any of those characters.
	local blockedChars = {
		"'", "\"", "\\", "/", "^",
		":", ".", ";", "&", ",", "%"
	}

	function string.MakeID(str)
		str = str:lower()
		str = str:gsub(" ", "_")

		for k, v in ipairs(blockedChars) do
			str = str:Replace(v, "")
		end

		return str
	end
end

-- A function to convers vararg to a string list.
function util.ListToString(callback, separator, ...)
	if (!isfunction(callback)) then
		callback = function(obj) return tostring(obj) end
	end

	if (!isstring(separator)) then
		separator = ", "
	end

	local list = {...}
	local result = ""

	for k, v in ipairs(list) do
		local text = callback(v)

		if (isstring(text)) then
			result = result..text
		end

		if (k < #list) then
			result = result..separator
		end
	end

	return result
end

-- A function to check whether a string is a number.
function string.isnumber(str)
	return (tonumber(str) != nil)
end

local bools = {
	["true"] = true,
	["false"] = false,
	["yes"] = true,
	["no"] = false
}

function string.isbool(str)
	return bools[str] != nil
end

-- A function to count character in a string.
function string.CountCharacter(str, char)
	local exploded = string.explode("", str)
	local hits = 0

	for k, v in ipairs(exploded) do
		if (v == char) then
			if (char == "\"") then
				local prevChar = exploded[k - 1] or ""

				if (prevChar == "\\") then
					continue
				end
			end

			hits = hits + 1
		end
	end

	return hits
end

-- INTERNAL: used to remove all newlines from table that is passed to BuildTableFromString.
function util.SmartRemoveNewlines(str)
	local exploded = string.explode("", str)
	local toReturn = ""
	local skip = ""

	for k, v in ipairs(exploded) do
		if (skip != "") then
			toReturn = toReturn..v

			if (v == skip) then
				skip = ""
			end

			continue
		end

		if (v == "\"") then
			skip = "\""

			toReturn = toReturn..v

			continue
		end

		if (v == "\n" or v == "\t") then
			continue
		end

		toReturn = toReturn..v
	end

	return toReturn
end

-- A function to build a table from string.
-- It has /almost/ the same syntax as Lua tables,
-- except key-values ONLY work like this {key = "value"},
-- so, NO {["key"] = "value"} or {[1] = value}, THOSE WON'T WORK.
-- This supports tables-inside-tables structure.
function util.BuildTableFromString(str)
	str = util.SmartRemoveNewlines(str)

	local exploded = string.explode(",", str)
	local tab = {}

	for k, v in ipairs(exploded) do
		if (!isstring(v)) then continue end

		if (!string.find(v, "=")) then
			v = v:RemoveTextFromStart(" ", true)

			if (string.IsNumber(v)) then
				v = tonumber(v)
			elseif (string.find(v, "\"")) then
				v = v:RemoveTextFromStart("\""):RemoveTextFromEnd("\"")
			elseif (v:find("{")) then
				v = v:Replace("{", "")

				local lastKey = nil
				local buff = v

				for k2, v2 in ipairs(exploded) do
					if (k2 <= k) then continue end

					if (v2:find("}")) then
						buff = buff..","..v2:Replace("}", "")

						lastKey = k2

						break
					end

					buff = buff..","..v2
				end

				if (lastKey) then
					for i = k, lastKey do
						exploded[i] = nil
					end

					v = util.BuildTableFromString(buff)
				end
			else
				v = v:RemoveTextFromEnd("}")
			end

			table.insert(tab, v)
		else
			local parts = string.explode("=", v)
			local key = parts[1]:RemoveTextFromEnd(" ", true):RemoveTextFromEnd("\t", true)
			local value = parts[2]:RemoveTextFromStart(" ", true):RemoveTextFromStart("\t", true)

			if (string.IsNumber(value)) then
				value = tonumber(value)
			elseif (value:find("{") and value:find("}")) then
				value = util.BuildTableFromString(value)
			else
				value = value:RemoveTextFromEnd("}")
			end

			tab[key] = value
		end
	end

	return tab
end