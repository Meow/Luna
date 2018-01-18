luna.pp:AddProcessor("ops", function(code)
	code = code:gsub("([%w_%.%:]+)%s-%+=%s-([^\n;]+)","%1=%1+(%2)")						// +=
	code = code:gsub("([%w_%.%:]+)%s-%-=%s-([^\n;]+)","%1=%1-(%2)") 					// -=
	code = code:gsub("([%w_%.%:]+)%s-%*=%s-([^\n;]+)","%1=%1*(%2)") 					// *=
	code = code:gsub("([%w_%.%:]+)%s-%/=%s-([^\n;]+)","%1=%1/(%2)") 					// /=
	code = code:gsub("([%w_%.%:]+)%s-%%=%s-([^\n;]+)","%1=%1%%(%2)")					// %=
	code = code:gsub("([%w_%.%:]+)%s-%^=%s-([^\n;]+)","%1=%1^(%2)") 					// ^=
	code = code:gsub("([%w_%.%:]+)%s-and=%s-([^\n;]+)","%1=%1&&(%2)")					// and=
	code = code:gsub("([%w_%.%:]+)%s-or=%s-([^\n;]+)","%1=%1||(%2)")					// or=
	code = code:gsub("([%w_%.%:]+)%s-%%.%.=%s-([^\n;]+)","%1=%1..(%2)")				// ..=
	code = code:gsub("([%w_%.%:]+)%s-||=%s-([^\n;]+)","%1=%1||(%2)") 					// ||=
	code = code:gsub("([%w_%.%:]+)%s-&&=%s-([^\n;]+)","%1=%1&&(%2)") 					// &&=
	code = code:gsub("([%w_%.%:]+)%s-|=%s-([^\n;]+)","%1=bit.bor(%1,(%2))") 	// |=
	code = code:gsub("([%w_%.%:]+)%s-&=%s-([^\n;]+)","%1=bit.band(%1,(%2))") 	// &=
	code = code:gsub("([%w_%.%:]+)%s-&%s-([%w_]+)"," bit.band(%1,(%2))") 			// &
	code = code:gsub("([%w_%.%:]+)%s-|%s-([%w_]+)"," bit.bor(%1,(%2))") 			// |
	code = code:gsub("([%w_%.%:]+)%s-<<%s-([^\n;]+)"," bit.lshift(%1,(%2))") 	// <<
	code = code:gsub("([%w_%.%:]+)%s->>%s-([^\n;]+)"," bit.rshift(%1,(%2))") 	// >>

	code = code:gsub("%+%+([%w_%.%:]+)","(function() %1=%1+1 return %1 end)()") // ++a
	code = code:gsub("([%w_%.%:]+)%+%+","(function() %1=%1+1 return %1-1 end)()")//a++

	/*code = code:gsub("using%s+([%w_%d%.]+)",function(lib) //using library/function 
		local name = string.Explode(".",lib)
		local path = _G

		for _,v in pairs(name) do
			path = path[v]
		end

		if (type(path) == "function") then
			name = name[#name]
			return "local "..name.."="..lib
		elseif (type(path) == "table") then
			local ret = ""
			for k,v in pairs(path) do
				ret = ret.."local "..k.."="..lib.."."..k..";"
			end
			return ret
		end
	end)*/

	return code
end)