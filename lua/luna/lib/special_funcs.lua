local function is_number(str)
	return str:match("%d")
end

local special_funcs = {
	["to_s"] = "tostring(%1)%2",
	["to_n"] = "tonumber(%1)%2",
	["to_b"] = "tobool(%1)%2",
	["is_s"] = "isstring(%1)%2",
	["is_b"] = "isbool(%1)%2",
	["is_n"] = "isnumber(%1)%2",
	["is_t"] = "istable(%1)%2",
	["is_f"] = "isfunction(%1)%2",
	["str?"] = "isstring(%1)%2",
	["bool?"] = "isbool(%1)%2",
	["num?"] = "isnumber(%1)%2",
	["tab?"] = "istable(%1)%2",
	["func?"] = "isfunction(%1)%2",
	["presence"] = "\3\4(function()if(%1!=nil&&%1!=''&&(istable(%1)&&table.Count(%1)>0||true))then return %1 else return nil end end)()\4\3%2"
}

function register_special_func(name, replacement)
	special_funcs[name] = replacement
end

register_special_func("upper", "string.upper(%1)%2")
register_special_func("lower", "string.lower(%1)%2")

function luna.pp:RegisterSpecialFunction(a, b)
	special_funcs[a] = b
end

luna.pp:AddProcessor("special_funcs", function(code)
	-- a.is_a? b
	code = code:gsub("([%w_'\"%?]+)%.is_a%?%s-([%w_]+)", function(a, b)
		return "(string.lower(type("..a.."))==\""..string.lower(b).."\")"
	end)

	for k, v in pairs(special_funcs) do
		code = code:gsub("([%w_'\"%?]+)%."..string.pattern_safe(k).."([^%w_])", v)
	end

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