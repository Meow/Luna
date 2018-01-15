local cookies = {}
local lastCookie = ""

function cookie.Get(key)
	if (REQUEST.Cookie != lastCookie) then
		
		lastCookie = REQUEST.Cookie
	end

	return cookies[key]
end