luna.pp:AddProcessor("switch", function(code)
  local switch_pattern = "switch%s*%(?%s*([%w_+%.:]+)%s*%)?%s*\n"
  local s, e, condition = code:find(switch_pattern)

  while (s) do
    local switch_end, real_end = luna.util.FindLogicClosure(code, e, 1)

    if (switch_end) then
      local block = code:sub(e, real_end)
      local lines = block:split("\n")
      local els = false
      local cond_count = 0
      local cond = ""
      local result = ""

      for k, v in ipairs(lines) do
        if (v:find("case%s")) then
          local line_cond = v:match("%s*case%s*([^\n]+)")
  
          if (cond_count > 0) then
            cond = cond.." || "
          end
  
          cond = cond.."("..condition.." == "..line_cond..")"
          cond_count = cond_count + 1
          lines[k] = ""
        elseif (cond != "") then
          if (!els) then
            lines[k - 1] = "if ("..cond..") then"
            els = true
          else
            lines[k - 1] = "elseif ("..cond..") then"
          end

          cond_count = 0
          cond = ""
        end
      end

      for k, v in ipairs(lines) do
        if (v != "") then
          result = result..v.."\n"
        end
      end

      if (result != "") then
        code = luna.pp:PatchStr(code, s, real_end, result)
      end
    end

    s, e, cond = code:find(switch_pattern, real_end or e)
  end

  return code
end)