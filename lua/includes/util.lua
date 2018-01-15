function table.GetKeys(tab)
	local keys = {}
	local id = 1

	for k, v in pairs(tab) do
		keys[id] = k
		id = id + 1
	end

	return keys
end

--[[---------------------------------------------------------
	Prints a table to the console
-----------------------------------------------------------]]
function PrintTable(t, indent, done)
	done = done or {}
	indent = indent or 0
	local keys = table.GetKeys(t)

	table.sort(keys, function(a, b)
		if (isnumber(a) and isnumber(b)) then return a < b end
		return tostring(a) < tostring(b)
	end)

	for i = 1, #keys do
		local key = keys[i]
		local value = t[key]
		Msg(string.rep("\t", indent))

		if  (istable(value) and !done[value]) then
			done[value] = true
			Msg(tostring(key)..":".."\n")
			PrintTable(value, indent + 2, done)
			done[value] = nil
		else
			Msg(tostring(key).."\t=\t")
			Msg(tostring(value).."\n")
		end
	end
end

function TimeToExpiresToken(time)
	return os.date("%a, %d %b %Y %H:%M:%S GMT", time)
end

do
	local tryCache = {}

	function try(tab)
		tryCache = {}
		tryCache.f = tab[1]

		local args = {}

		for k, v in ipairs(tab) do
			if (k != 1) then
				table.insert(args, v)
			end
		end

		tryCache.args = args
	end

	function catch(handler)
		local func = tryCache.f
		local args = tryCache.args or {}
		local result = {pcall(func, unpack(args))}
		local success = result[1]
		table.remove(result, 1)

		handler = handler or {}
		tryCache = {}

		SUCCEEDED = true

		if (!success) then
			SUCCEEDED = false

			if (isfunction(handler[1])) then
				handler[1](unpack(result))
			else
				ErrorNoHalt("[Exception] Failed to run the function!\n")
				ErrorNoHalt(unpack(result), "\n")
			end
		elseif (result[1] != nil) then
			return unpack(result)
		end
	end

	--[[
		Please note that the try-catch block will only
		run if you put in the catch function.

		Example usage:

		try {
			function()
				print("Hello World")
			end
		} catch {
			function(exception)
				print(exception)
			end
		}

		try {
			function(arg1, arg2)
				print(arg1, arg2)
			end, "arg1", "arg2"
		} catch {
			function(exception)
				print(exception)
			end
		}
	--]]
end