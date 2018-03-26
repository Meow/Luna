//
// Luna-style dots and colons
// Breaks your ability to simply copy-paste Lua into Luna
//

local blocked_binops = {
	["="] = true,
	["or="] = true,
	["||="] = true,
	["&&="] = true,
	["and="] = true,
	["+="] = true,
	["-="] = true,
	["/="] = true,
	["*="] = true,
	["&="] = true,
	["|="] = true,
	["%="] = true,
	["^="] = true,
	["..="] = true
}

local function check_nxt_safety(code, pos)
  local rdy = false

  for i = pos, code:len() do
    local v = code[i]

    if v == "\n" then return true end
    if v == "," then return false end
    if v == " " then rdy = true continue end
    if (!rdy) then continue end

    for k, v in pairs(blocked_binops) do
      if code:sub(i, i + k:len() - 1) == k then
        return false
      end
    end

    if v:match("%w") then return true end
  
    if v == "=" and code[i + 1] != "=" then
      return false
    end
  end

  return true
end

luna.pp:AddProcessor("punctuation", function(code)
  local lines = code:split("\n")
  local result = ""

  for _, line in ipairs(lines) do
    local hits = string.find_all(line, "[%w_]+%.")
    local chain = false
    local offset = 0

    for k, v in ipairs(hits) do
      local str, s, e = v[1], v[2] + offset, v[3] + offset
      local prev_c = line[s - 1]
      local next_c = line[e + 1]

      if chain and prev_c != "." then
        chain = false
      end

      -- ignore the :style writing.
      if chain or prev_c == ":" then
        if prev_c == ":" then
          line = luna.pp:PatchStr(line, s - 1, s - 1, "")
          offset = offset - 1
        end

        if next_c:match("%w_") then
          chain = true
        else
          chain = false
        end
      elseif next_c != "." and check_nxt_safety(line, e + 1) then
        line = luna.pp:PatchStr(line, e, e, ":")
      end
    end
 
    result = result..line.."\n"
  end

  result = result:gsub("([%w_]+)::([%w_]+)", function(a, b)
    if !_G[a] then
      local _a = string.lower(a[1])..a:sub(2, a:len())

      if _G[_a] then
        a = _a
      elseif _G[string.lower(a)] then
        a = string.lower(a)
      end
    end

    return a.."."..b
  end)

  return result
end)
