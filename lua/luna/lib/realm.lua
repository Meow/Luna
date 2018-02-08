-- TODO
-- TODO
-- TODO

LUNA_REALM = getenv("LUNA_REALM") or "sv"

luna.pp:AddProcessor("realm_resolver", function(code)
  local lines = code:split("\n")

	for line_n, line in ipairs(lines) do
		if (line:find("if%s-%(?SERVER%)?%s-then")) then

		end
	end

	return code
end)