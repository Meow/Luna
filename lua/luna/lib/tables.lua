luna.pp:AddProcessor("js_tables", function(code)
  local s, e = code:find("{")

  while (s) do
    local closure = luna.util.FindTableClosure(code, s)

    if (closure) then
      local block = code:sub(s, closure)

      code = luna.pp:PatchStr(code, s, closure, block:gsub("([%w_]+)%s-:%s-([^%w_])", "%1 = %2"))
    end

    s, e = code:find("{", closure or e + 1)
  end

	return code
end)