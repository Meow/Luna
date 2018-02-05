local macros = {
	["func"] = "function",
	["elsif"] = "elseif",
	["elif"] = "elseif",
	["yes"] = "true",
	["no"] = "false",
	["is"] = "==",
	["is not"] = "!="
}

luna.pp:AddProcessor("macros", function(code)
	code = save_strings(code)

	for k, v in pairs(macros) do
		local s, e = string.find(code, k.."[%s%(%)%[%]]")

		while (s) do
			if (!code:sub(s - 1, s - 1):match("[%w_]")) then
				code = (s != 1 and code:sub(1, s - 1) or "")..v..code:sub(e, code:len())
			end

			s, e = string.find(code, k.."[%s%(%)%[%]]", e)
		end
	end

	code = code:gsub("([%d%-]+)%.%.([%d%-]+)", function(a, b)
		local result = "{"

		a = tonumber(a)
		b = tonumber(b)

		for i = a, b, (a <= b and 1 or -1) do
			result = result..i..(i != b and "," or "")
		end

		return result.."}"
	end)

	code = restore_strings(code)

	return code
end)