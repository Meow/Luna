local definitions = {}
local def_blocks = {}
local last_id = 0

local function do_define(code)
	code = code:gsub("#ifdef%s+([%w_]+)%s*\n([^%z]+)#end", function(condition, block)
		last_id = last_id + 1
		def_blocks[last_id] = {condition, block}

		return "\4"..last_id.."\4"
	end)

	code = code:gsub("#ifndef%s+([%w_]+)%s*\n([^%z]+)#end", function(condition, block)
		last_id = last_id + 1
		def_blocks[last_id] = {condition, block, true}

		return "\4"..last_id.."\4"
	end)

	code = code:gsub("#define%s+([%w_]+)%s*([^%z]+)\n", function(d, val)
		definitions[d] = val

		return ''
	end)

	return code
end

luna.pp:AddProcessor("define", function(code)
--	code = do_define(code)

--	for k, v in ipairs(def_blocks) do
--		code = code:gsub("\4"..last_id.."\4", function()
--			if (definitions[v[1]] or v[3]) then
--				return v[2]
--			end

--			return ''
--		end)

--		code = do_define(code)
--	end

--	last_id = 0

	return code
end)
