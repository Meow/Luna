luna.pp:AddProcessor("pretty_loops", function(code)
  code = code:gsub("([%s\n])([^\n]+)%.each%s+([^\n]+)%s+do", "%1for %3 in ipairs(%2) do")
  code = code:gsub("([%s\n])([^\n]+)%.pairs%s+([^\n]+)%s+do", "%1for %3 in pairs(%2) do")

	return code
end)