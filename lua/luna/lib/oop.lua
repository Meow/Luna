-- TODO
-- TODO
-- TODO

local classes = {}

local function process_definition(code)
  local s, e = code:find("class")
end

local function process_instantiation(code)

end

luna.pp:AddProcessor("oop", function(code)
  code = process_definition(code)
  code = process_instantiation(code)

	return code
end)