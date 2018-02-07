local function is_number(str)
	return str:match("%d")
end

function __check_presence(obj)
	if obj != nil and obj != '' and obj != {} then
		return obj
	end

	return nil
end

function __is_a(a, b)
	return string.lower(type(a)) == b
end

local special_funcs = {
	["to_s"] = "tostring",
	["to_n"] = "tonumber",
	["to_b"] = "tobool",
	["is_s"] = "isstring",
	["is_b"] = "isbool",
	["is_n"] = "isnumber",
	["is_t"] = "istable",
	["is_f"] = "isfunction",
	["str?"] = "isstring",
	["bool?"] = "isbool",
	["num?"] = "isnumber",
	["tab?"] = "istable",
	["func?"] = "isfunction",
	["presence"] = "__check_presence"
}

function register_special_func(name, replacement)
	special_funcs[name] = replacement
end

register_special_func("upper", "string.upper")
register_special_func("lower", "string.lower")

function luna.pp:RegisterSpecialFunction(a, b)
	special_funcs[a] = b
end

luna.pp:AddProcessor("special_funcs", function(code)
	-- No arguments
	local s, e, fn = code:find("%.([%w_%?!]+)")

	while (s) do
		local obj, pos = read_obj_backwards(code, s - 1)

		if (obj) then
			if (special_funcs[fn]) then
				code = luna.pp:PatchStr(code, pos, e, special_funcs[fn].."("..obj..")")
			elseif (obj:match("%d+") and math[fn]) then
				code = luna.pp:PatchStr(code, pos, e, "math."..fn.."("..obj..")")
			elseif (string[fn]) then
				code = luna.pp:PatchStr(code, pos, e, "string."..fn.."("..obj..")")
			elseif (table[fn]) then
				code = luna.pp:PatchStr(code, pos, e, "table."..fn.."("..obj..")")
			end
		end

		s, e, fn = code:find("%.([%w_%?!]+)", e)
	end

	-- a.is_a? b
	code = code:gsub("([%w_'\"%?]+)%.is_a%?%s-([%w_]+)", function(a, b)
		return "(__is_a("..a..")==\""..string.lower(b).."\")"
	end)

	-- "any string".any_method
	--                string                func           args      ending
	code = code:gsub("['\"]([^%z\n]+)['\"]%.([%w_]+)[%(%s]?([^%z\n]*)([%)\n])", function(a, b, c, d)
		c = c:trim()
		return "string."..b.."([["..a.."]]"..((c and c != "") and ", "..c or "")..")"..(d != ")" and d or "")
	end)

	-- [[any string]].any_method
	code = code:gsub("%[%[([^%z\n]+)%]%]%.([%w_]+)[%(%s]?([^%z\n]*)([%)\n])", function(a, b, c, d)
		c = c:trim()
		return "string."..b.."([["..a.."]]"..((c and c != "") and ", "..c or "")..")"..(d != ")" and d or "")
	end)

	-- 123.any_method
	--                digit         func            args     ending
	code = code:gsub("([%-]?[%d]+)%.([%w_]+)[%(%s]?([^%z\n]*)([%)\n])", function(a, b, c, d)
		return "math."..b.."("..a..((c and c != "") and ", "..c or "")..")"..(d != ")" and d or "")
	end)

	-- a.any_method!
	while (code:find("([%w_'\"%(%):]+)%.([%w_]+)![%(%s]?([^%z\n%)]*)([%)\n])")) do
		code = code:gsub("([%w_'\"%(%):]+)%.([%w_]+)![%(%s]?([^%z\n%)]*)([%)\n])", function(a, b, c, d)
			return "(function() local _r="..a..":"..b.."("..c..") "..a.."=_r return "..a.." end)()"..(d == "\n" and d or "")
		end)
	end

	return code
end)
