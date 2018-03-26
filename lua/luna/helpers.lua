function printc(color, ...)
  local pieces = {...}

  for k, v in ipairs(pieces) do
    MsgC(v, color)

    if (k < #pieces) then
      MsgC("\t", color)
    end
  end

  MsgC("\n", color)
end

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

    local fstr, fend, sp, word = code:find("(%s*)([^%s\n%(%)%[%]]+)", i)

    -- functions as args
    if (word == "function") then
      local context_end, real_end = luna.util.FindLogicClosure(code, fend, 1)

      if (context_end) then
        skip = code:sub(i, real_end):len() - 1
        continue
      end
    end

    if (!started and v != "-" and LUA_OP_SYMBOLS[v]) then
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

    local fstr, fend, comma, sp, word = code:find("([,]?)(%s*)([^%s\n%(%)%[%]]+)", i)

    -- functions as args
    if (word == "function") then
      local context_end, real_end = luna.util.FindLogicClosure(code, fend, 1)

      if (context_end) then
        if (comma == ",") then
          local substr = code:sub(i, real_end)
          skip = code:sub(i, real_end):len()

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
      local st, ed = line:find("do")

      -- Yield
      if (st) then
        -- Yield blocks are usually at the end of function call,
        -- enforce the value.
        e = st - 1
        ending = "\n"
      end

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

function read_string(code, pos)
	local str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1
	local ignore_until = false
	local i = pos

	while (i < code:len()) do
		i = i + 1

		local v = code:sub(i, i)

		if (ignore_until) then
			if (ignore_until == v) then
				ignore_until = false
			end

			continue
		end

		if (v == "{" and code:sub(i - 1, i - 1) == "#") then
			ignore_until = "}"

			continue
		end

		if (str_open) then
			if (v != close_char) then
				continue
			elseif (code:sub(i, i + close_seq:len() - 1) == close_seq) then
				return open_pos, i, open_char, close_char, open_seq, close_seq
			end
		end

		if (v == "\"" or v == "'") then
			str_open = true
			open_char = v
			open_seq = v
			close_char = v
			close_seq = v
			open_pos = i
		elseif (v == "[" and code:sub(i + 1, i + 1) == "[") then
			str_open = true
			open_char = "["
			open_seq = "[["
			close_char = "]"
			close_seq = "]]"
			open_pos = i
		end
	end

	return nil
end

function read_string_backwards(code, pos)
	local str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1
	local ignore_until = false
	local i = pos

	while (i > 0) do
		i = i - 1

		local v = code:sub(i, i)

		if (ignore_until) then
			if (ignore_until == v) then
				ignore_until = false
			end

			continue
		end

		if (str_open) then
			if (v != close_char) then
				continue
			elseif (code:sub(i - close_seq:len() + 1, i) == close_seq) then
				return open_pos, i, open_char, close_char, open_seq, close_seq
			end
		end

		if (v == "\"" or v == "'") then
			str_open = true
			open_char = v
			open_seq = v
			close_char = v
			close_seq = v
			open_pos = i
		elseif (v == "]" and code:sub(i - 1, i - 1) == "]") then
			str_open = true
			open_char = "]"
			open_seq = "]]"
			close_char = "["
			close_seq = "[["
			open_pos = i
		end
	end

	return nil
end

local opposites = {
  ["{"] = "}",
  ["("] = ")",
  ["["] = "]",
  ["}"] = "{",
  [")"] = "(",
  ["]"] = "["
}

function read_obj(code, pos)
  local buf = ""
  local ignore_until_pos = nil
  
  for i = pos, code:len() do
    local v = code[i]

    if (ignore_until_pos and ignore_until_pos != i) then
      buf = buf..v

      continue
    else
      ignore_until_pos = nil
    end

    if (buf == "" and v:match("%s")) then continue end

    if (v == "{" or v == "(" or v == "[") then
      local closer = luna.util.FindTableClosure(code, i, 0, v, opposites[v])

      if (closer != -1) then
        ignore_until_pos = closer
      end
    end

    if (v == "\"" or v == "'" or v == "[" and code[i + 1] == "[") then
      local open, close = read_string(code, i)

      if (close) then
        ignore_until_pos = close
      end
    end

    if (v == " ") then
      return buf, i - 1
    end

    buf = buf..v
  end

  if (buf != "") then
    return buf, code:len()
  end

  return nil
end

function read_obj_backwards(code, pos)
  local buf = ""
  local ignore_until_pos = nil
  
  for i = pos, 1, -1 do
    local v = code[i]

    if (ignore_until_pos and ignore_until_pos != i) then
      buf = buf..v

      continue
    else
      ignore_until_pos = nil
    end

    if (buf == "" and v:match("%s")) then continue end

    if (v == "}" or v == ")" or v == "]") then
      local closer = luna.util.FindTableClosure(code, i, 0, v, opposites[v])

      if (closer != -1) then
        ignore_until_pos = closer
      end
    end

    if (v == "\"" or v == "'" or v == "]" and code[i - 1] == "]") then
      local open, close = read_string_backwards(code, i)

      if (close) then
        ignore_until_pos = close
      end
    end

    if (v == " " or v == "\n") then
      return string.reverse(buf), i + 1
    end

    buf = buf..v
  end

  if (buf != "") then
    return string.reverse(buf), 1
  end

  return nil
end

function char_count(str, c)
  local count = 0

  for i = 1, str:len() do
    if (str[i] == c) then
      count = count + 1
    end
  end

  return count
end
