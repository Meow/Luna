local function shoot(line, init, size, where)
  size = size or 1

  for i = init, where and 1 or line:len(), where and -1 or 1 do
    if !line[i]:match("%s") then
      if where then
        return line:sub(i - size + 1, i)
      else
        return line:sub(i, i + size - 1)
      end
    end
  end
end

local function check_safety(line, pos)
  local c, nxt, prv = line[pos], line[pos + 1], line[pos - 1]

  -- check if in table or otherwise shouldn't be local
  if (line:ends(",") or prv == "{") then return false end

  local char = shoot(line, pos - 1, 1, true)

  if (char == "{" or LUA_OP_SYMBOLS[char]) then return false end

  return true
end

luna.pp:AddProcessor("local_by_default", function(code)
  local contexts = luna.pp:GetContexts(code)
  local locals = {}
  local lines = code:split("\n")
  local result = ""
  local indent = nil
  local tabl = 0

  for l_num, line in ipairs(lines) do
    tabl = tabl + char_count(line, "{")
    tabl = tabl - char_count(line, "}")

    if (tabl > 0) then
      continue
    end

    if (line:find("global:")) then
      indent = line:match("([%s]*)global:")
      lines[l_num] = lines[l_num]:gsub("global:", "")

      continue
    end

    if (indent and line:trim() != '') then
      local cur_indent = line:match("^([%s]+)[%w_%.%:]")

      if (cur_indent and cur_indent:len() > indent:len()) then
        continue
      else
        indent = nil
      end
    end

    -- Quick and dirty global keyword check. Yes, I know it's not required to be at the beginning of the statement.
    -- Let's call this an 'unintended feature'...
    if (!line:find("global[%s%(]+") and !line:find("glob[%s%(]+") and !line:find("local%s+")) then
      local s, e, vars = line:find("([%w_,%.]+)%s-=[^=]")

      if (s and !vars:find("function") and !vars:find("%.")) then
        local vars_table = vars:split(",")
        local context = luna.pp:GetContext(s) or {0, 0, 0}
        locals[context[2]] = locals[context[2]] or {}
        local new_locals = locals[context[2]]
        local should_place_local_sign = false

        for k, v in ipairs(vars_table) do
          v = v:trim()

          if (!new_locals[v] and !_G[v] and !LUA_OPERATORS[v] and check_safety(line, s)) then
            should_place_local_sign = true
            new_locals[v] = v
          end
        end

        locals[context[2]] = new_locals

        if (should_place_local_sign) then
          lines[l_num] = luna.pp:PatchStr(line, s, s, "local "..line:sub(s, s))
        end
      else
        s, e, vars = line:find("function%s[^%(\n]+%(([^%)]+)%)")

        if (s and vars:trim() != "") then
          local vars_table = vars:split(",")
          local context = luna.pp:GetContext(e) or {0, 0, 0}
          locals[context[2]] = locals[context[2]] or {}
          local new_locals = locals[context[2]]

          for k, v in ipairs(vars_table) do
            v = v:trim()

            if (!new_locals[v] and !LUA_OPERATORS[v]) then
              new_locals[v] = v
            end
          end

          locals[context[2]] = new_locals
        end
      end
    else
      lines[l_num] = line:gsub("global%s?", ""):gsub("glob%s", "")
    end
  end

  for k, v in ipairs(lines) do
    result = result..v.."\n"
  end

  if (result != "") then
    return result
  end

	return code
end)
