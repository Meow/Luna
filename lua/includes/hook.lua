-- Hooks system.
hook = hook or {};

local stored = hook.stored or {}
hook.stored = stored

function hook.Call(hookName, ...)
	if (stored[hookName]) then
		for k, v in pairs(stored[hookName]) do
			local a, b, c, d, e, f, g, h = v(...)

			if (a != nil) then
				return a, b, c, d, e, f, g, h
			end
		end
	end

	return nil
end

function hook.Run(id, ...)
	return hook.Call(id, ...)
end

function hook.Add(hookName, uniqueID, callback)
	stored[hookName] = stored[hookName] or {}

	stored[hookName][uniqueID] = callback
end

function hook.Remove(hookName, uniqueID)
	if (hookName and uniqueID) then
		if (stored[hookName] and stored[hookName][uniqueID]) then
			stored[hookName][uniqueID] = nil
		end
	end
end