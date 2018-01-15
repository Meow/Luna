library = library or {}

function library.New(id, parent)
	parent = parent or _G

	if (!istable(parent)) then return end

	parent[id] = parent[id] or {}

	return parent[id]
end

-- Set library table's Metatable so that we can call it like a function.
setmetatable(library, {__call = function(tab, strName, tParent) return tab.Get(strName, tParent) end})

-- A function to create a new class. Supports constructors and inheritance.
function library.NewClass(strName, tParent, CExtends)
	local class = {
		-- Same as "new ClassName" in C++
		__call = function(obj, ...)
			local newObj = {}

			-- Set new object's meta table and copy the data from original class to new object.
			setmetatable(newObj, obj)
			table.SafeMerge(newObj, obj)

			-- If there is a base class, call their constructor.
			local baseClass = obj.BaseClass
			local hasBaseclass = true

			while (istable(baseClass) and hasBaseclass) do
				if (isfunction(baseClass[baseClass.ClassName])) then
					try {
						baseClass[baseClass.ClassName], newObj, ...
					} catch {
						function(exception)
							ErrorNoHalt("Base class constructor has failed to run!\n"..tostring(exception.."\n"))
						end
					}
				end

				if (baseClass.BaseClass and baseClass.ClassName != baseClass.BaseClass.ClassName) then
					baseClass = baseClass.BaseClass
				else
					hasBaseclass = false
				end
			end

			-- If there is a constructor - call it.
			if (obj[strName]) then
				local success, value = pcall(obj[strName], newObj, ...)

				if (!success) then
					ErrorNoHalt("["..strName.."] Class constructor has failed to run!\n")
					ErrorNoHalt(value.."\n")
				end
			end

			newObj.IsValid = function() return true end

			-- Return our newly generated object.
			return newObj
		end
	}

	-- If this class is based off some other class - copy it's parent's data.
	if (istable(CExtends)) then
		local copy = table.Copy(CExtends)
		local merged = table.SafeMerge(copy, class)

		if (isfunction(CExtends.OnExtended)) then
			try {
				CExtends.OnExtended, copy, merged
			} catch {
				function(exception)
					ErrorNoHalt("OnExtended class hook has failed to run!\n"..tostring(exception.."\n"))
				end
			}
		end

		class = merged
	end

	-- Create the actual class table.
	local obj = library.New(strName, (tParent or _G))
	obj.ClassName = strName
	obj.BaseClass = CExtends or false

	library.lastClass = {name = strName, parent = (tParent or _G)}

	return setmetatable((tParent or _G)[strName], class)
end

function class(strName, CExtends, tParent)
	return library.NewClass(strName, tParent, CExtends)
end

function extends(CBaseClass)
	if (isstring(CBaseClass)) then
		CBaseClass = _G[CBaseClass]
	end

	if (istable(library.lastClass) and istable(CBaseClass)) then
		local obj = library.lastClass.parent[library.lastClass.name]
		local copy = table.Copy(CBaseClass)
		local merged = table.Merge(copy, obj)

		if (isfunction(CBaseClass.OnExtended)) then
			try {
				CBaseClass.OnExtended, copy, merged
			} catch {
				function(exception)
					ErrorNoHalt("OnExtended class hook has failed to run!\n"..tostring(exception.."\n"))
				end
			}
		end

		obj = merged
		obj.BaseClass = CBaseClass

		hook.Call("OnClassExtended", obj, CBaseClass)

		library.lastClass.parent[library.lastClass.name] = obj
		library.lastClass = nil

		return true
	end

	return false
end

--[[
	class "SomeClass" extends SomeOtherClass
	class "SomeClass" extends "SomeOtherClass"
--]]

-- Aliases for people who're hell bent on clarity.
implements = extends
inherits = extends

--[[
	Example usage:

	local obj = new "className"
	local obj = new("className", 1, 2, 3)
--]]
function new(className, ...)
	if (istable(className)) then
		return className(...)
	end

	return (_G[className] and _G[className](unpack(...)))
end