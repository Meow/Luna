luna.pp:AddProcessor("pretty_loops", function(code)
  code = code:gsub("[%s\n]([^\n]+)%.each%s+([^\n]+)%s+do", "for %2 in pairs(%1) do")
  code = code:gsub("[%s\n]([^\n]+)%.each_i%s+([^\n]+)%s+do", "for %2 in ipairs(%1) do")

	return code
end)