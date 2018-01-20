function is_next_statement(code, what, pos)
  local i = pos

  while (true) do
    if (i >= code:len()) then break end

    local v = code:sub(i, i)

    i = i + 1

    if (v:match("%s") or v == "\n") then continue end

    if (code:sub(i - 1, i + what:len() - 2) == what) then
      return true
    else
      return false
    end
  end

  return false
end

function read_argument(code, begin)
  local i = begin
  local opener = nil
  local ignore_until = nil
  local ignore_amt = nil
  local started = false
  local skip = 0

  while (true) do
    if (i - 1 > code:len()) then break end

    local v = code:sub(i, i)

    i = i + 1

    if (skip > 0) then
      skip = skip - 1

      continue
    end

    if (ignore_until) then
      if (ignore_amt == nil) then ignore_amt = 1 end

      if (opener == v) then
        ignore_amt = ignore_amt + 1

        continue
      end

      if (ignore_until == v) then
        if (ignore_amt > 0) then
          ignore_amt = ignore_amt - 1
        end

        if (ignore_amt == 0) then
          opener = nil
          ignore_until = nil
          ignore_amt = nil
        end
      end

      continue
    end

    local sp, word = code:match("(%s*)([^%s\n%(%)%[%]]+)", i)

    -- functions as args
    if (word == "function") then
      local context_end, real_end = luna.util.FindLogicClosure(code, i, 0)

      if (context_end) then
        skip = code:sub(i, real_end):len() - 1

        continue
      end
    end

    if (!started and v != "-" and LUA_OP_SYMBOLS[v]) then
      print("returning false for some reason")
      return false
    end

    if (v == "'" or v == "\"") then ignore_until = v end
    if (v == "{") then ignore_until = "}" opener = "{" continue end
    if (v == "(") then ignore_until = ")" opener = "(" continue end
    if (v == "[") then ignore_until = "]" opener = "[" continue end
    if (v == "]") then continue end

    if (v == "," or v == ")" or v == "\n" or i > code:len()) then
      local arg_list = code:sub(begin, i - 1):trim():trim("\t")

      if ((arg_list != "true" and arg_list != "false" and arg_list != "nil" and LUA_OPERATORS[arg_list]) or LUA_OP_SYMBOLS[arg_list]) then return false end

      return arg_list, begin, i - 1, code:sub(i - 1, i - 1)
    end

    started = true
  end

  return false
end

function read_arguments(code, begin, read_expressions, read_special)
  local i = begin
  local last_meaningful = ""
  local opener = nil
  local ignore_until = nil
  local ignore_amt = nil
  local started = false
  local skip = 0

  while (true) do
    if (i >= code:len()) then break end

    local v = code:sub(i, i)

    i = i + 1

    if (skip > 0) then
      skip = skip - 1

      continue
    end

    if (ignore_until) then
      if (ignore_amt == nil) then ignore_amt = 1 end

      if (opener == v) then
        ignore_amt = ignore_amt + 1

        continue
      end

      if (ignore_until == v) then
        if (ignore_amt > 0) then
          ignore_amt = ignore_amt - 1
        end

        if (ignore_amt == 0) then
          opener = nil
          ignore_until = nil
          ignore_amt = nil
        end

        last_meaningful = v
      end

      continue
    end

    if (read_expressions) then
      local word = code:match("([^%s\n%(%)]+)", i)

      -- We /definitely/ should stop now...
      if (word == "then") then
        local a = code:sub(begin, i - 1):trim():trim("\t")

        if (a:trim() == "") then return false end

        return a, begin, i - 1, code:sub(i - 1, i - 1)
      end

      local sp, wd = code:match("(%s*)([^%s\n%(%)%[%]]+)", i)

      if (wd == "or" or wd == "and" or LUA_EXPRESSION_WHITELIST[wd]) then
        skip = sp:len() + wd:len() + 1

        continue
      end
    end

    local comma, sp, word = code:match("([,]?)(%s*)([^%s\n%(%)%[%]]+)", i)

    -- functions as args
    if (word == "function") then
      local context_end, real_end = luna.util.FindLogicClosure(code, i, 0)

      if (context_end) then
        if (comma == ",") then
          skip = code:sub(i, real_end):len() - 1

          continue
        elseif (read_special) then -- yielded blocks
          return code:sub(begin, real_end), begin, real_end, code:sub(real_end, real_end)
        end
      end
    end

    if (read_special) then
      local eol = code:find("\n", i)
      local line = code:sub(i, code:find("\n", i))
      local s, e, name, val, ending = line:find("([%w_]+):%s*([^,\n]+)([\n,])")

      if (s) then
        skip = e - 1

        if (ending == "\n") then
          local end_pos = i + e - 2
          return code:sub(begin, end_pos), begin, end_pos, code:sub(end_pos, end_pos)
        end

        continue
      end
    end

    if (!started and v != "-" and LUA_OP_SYMBOLS[v]) then
      return false
    end

    if (v == "=" and code:sub(i + 1, i + 1) == "=") then ignore_until = " " end
    if (v == "'" or v == "\"") then ignore_until = v end
    if (v == "{") then ignore_until = "}" opener = "{" continue end
    if (v == "(") then ignore_until = ")" opener = "(" continue end
    if (v == "[") then ignore_until = "]" opener = "[" continue end
    if (v == "\n" and last_meaningful == ",") then continue end
    if (v == "]") then continue end
    if ((last_meaningful == "," or last_meaningful == "") and (v:match("%s") or v == "\n")) then continue end

    -- and we finally reached the end of this thing
    if (last_meaningful != "" and v:match("%s") or v == "\n") then
      if (!is_next_statement(code, "=", i)) then
        local arg_list = code:sub(begin, i - 1):trim():trim("\t")

        if ((arg_list != "true" and arg_list != "false" and arg_list != "nil" and LUA_OPERATORS[arg_list]) or LUA_OP_SYMBOLS[arg_list]) then return false end

        return arg_list, begin, i - 1, code:sub(i - 1, i - 1)
      else
        return false
      end
    end

    started = true
    last_meaningful = v
  end

  return false
end