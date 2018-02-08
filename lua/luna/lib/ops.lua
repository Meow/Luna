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

	return code
end)