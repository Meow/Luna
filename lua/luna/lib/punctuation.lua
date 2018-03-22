//
// Luna-style dots and colons
// Breaks your ability to simply copy-paste Lua into Luna
//

luna.pp:AddProcessor("punctuation", function(code)
  local lines = code:split("\n")
  local result = ""

  for _, line in ipairs(lines) do
    local hits = string.find_all(line, "[%w_]+%.")
    local chain = false

    for k, v in ipairs(hits) do
      local str, s, e = v[1], v[2], v[3]
      local prev_c = line[s - 1]
      local next_c = line[e + 1]

      if chain and prev_c != "." then
        chain = false
      end

      -- ignore the :style writing.
      if chain or prev_c == ":" then
        if prev_c == ":" then
          line = luna.pp:PatchStr(line, s - 1, s - 1, "")
        end

        if next_c:match("%w_") then
          chain = true
        else
          chain = false
        end
      elseif next_c != "." then
        line = luna.pp:PatchStr(line, e, e, ":")
      end
    end
 
    result = result..line.."\n"
  end

  result = result:gsub("([%w_]+)::([%w_]+)", function(a, b)
    if !_G[a] then
      local _a = _G[string.lower(a[1])..a:sub(2, a:len())]

      if _a then
        a = _a
      elseif _G[string.lower(a)] then
        a = _G[string.lower(a)]
      end
    end

    return a.."."..b
  end)

  return result
end)
