luna.pp:AddProcessor("switch", function(code)
  local switch_pattern = "switch%s*%(?%s*([%w_+%.:]+)%s*%)?%s*\n"
  local s, e, cond = code:find(switch_pattern)

  while (s) do
    local switch_end, real_end = luna.util.FindLogicClosure(code, e, 1)

    if (switch_end) then
      local block = code:sub(e, real_end)
      local els = false
  
      block = block:gsub("%s*case%s*([^\n]+)", function(a)
        if (!els) then
          els = true

          return "if ("..cond.." == "..a..") then"
        else
          return "elseif "..cond.." == "..a.." then"
        end
      end)

      code = luna.pp:PatchStr(code, s, real_end, block)
    end

    s, e, cond = code:find(switch_pattern, real_end or e)
  end

  return code
end)