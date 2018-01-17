local function is_next_statement(code, what, pos)
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

local function read_arguments(code, begin)
  local i = begin
  local last_meaningful = ""
  local ignore_until = nil
  local started = false

  while (true) do
    if (i >= code:len()) then break end

    local v = code:sub(i, i)

    i = i + 1

    if (ignore_until) then
      if (ignore_until == v) then
        ignore_until = nil
      end

      continue
    end

    if (!started and v != "-" and LUA_OP_SYMBOLS[v]) then
      return false
    end

    if (v == "'" or v == "\"") then ignore_until = v end
    if (v == "{") then ignore_until = "}" continue end
    if (v == "(") then ignore_until = ")" continue end
    if (v == "[") then ignore_until = "]" continue end
    if (v == "\n" and last_meaningful == ",") then continue end
    if (v == "]") then continue end
    if ((last_meaningful == "," or last_meaningful == "") and (v:match("%s") or v == "\n")) then continue end

    -- and we finally reached the end of this shit
    if (last_meaningful != "" and (v == "\n" or v:match("%s"))) then
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

local blocked_arg_strings = {
  "end", "then", "in", "pairs", "pairs(", "ipairs", "ipairs("
}

local function fix_bracket_argumented_call(code, bracket_start)
  local arg_str, s, e, end_char = read_arguments(code, bracket_start)

  if (arg_str) then
    for k, v in ipairs(blocked_arg_strings) do
      if (arg_str:find("[^%w]?"..string.pattern_safe(v).."[^%w]") or arg_str == v) then
        return code
      end
    end

    code = luna.pp:PatchStr(code, s, s, "(")
    code = luna.pp:PatchStr(code, e, e, ")"..end_char)
  end

  return code
end

-- Fix missing parentheses on function calls.
local function fix_brackets(code)
  -- a:b
  code = code:gsub("([%w_%.]+):([%w_]+)%s*\n", "%1:%2()\n")

  -- Function definition
  code = code:gsub("function ([%w_%.]+)([%s\n])", "function %1()%2")

  -- Any argumented function call
  local s, e, t = code:find("([%w_]+)%s+[^%z\n%s]")

  while (s) do
    if (!LUA_OPERATORS[t]) then
      code = fix_bracket_argumented_call(code, e - 1)
    end

    s, e, t = code:find("([%w_]+)%s+[^%z\n%s]", e)
  end

  -- Argument-less function call
  -- a?
  code = code:gsub("([%w_]+)__bool([%s\n])", "%1__bool()%2")

  return code
end

-- Fix missing then
local function fix_conditions(code)
  local s, e = code:find("if")
  
  while (s) do
    local args, st, en, en_char = read_arguments(code, e + 1)
  
    if (args and !args:ends("then") and !is_next_statement(code, "then", en)) then
      local should_fix = true
  
      for k, v in pairs(LUA_OP_SYMBOLS) do
        if (is_next_statement(code, k, en)) then
          should_fix = false
        end
      end

      if (should_fix) then code = luna.pp:PatchStr(code, st, en, " "..args.." then"..en_char) end
    end

    s, e = code:find("if", e)
  end

  return code
end

-- Indentantion blocks (end-less logical blocks)
local function indent_blocks(code)
  local s, e = code:find("if[^%z]-then")

  while (s) do
    local closure = luna.util.FindLogicClosure(code, e, 2)

    -- Mismatched end amount
    if (closure == -1) then
      local ending = code:find("\n", e)
      local remainder = code:sub(e + 1, ending):trim():trim("\t"):trim("\n")

      if (remainder != "") then
        if (!remainder:ends("end")) then
          code = luna.pp:PatchStr(code, ending + 1, ending + 1, " end\n")
        end
      else
        local line = code:sub(ending + 2, code:find("\n", ending + 2))
        local indent = line:match("([%s]+)[^%z]+") or ""

        if (indent != "") then
          local line_start = code:find("\n", ending + line:len() + 2)

          while (line_start) do
            local line_end = code:find("\n", line_start + 1)
            line = code:sub(line_start + 1, line_end - 1)

            local line_indent = line:match("([%s]+)[^%z]+") or ""

            if (!line:trim():trim("\t"):starts("else") and line_indent:len() < indent:len()) then
              code = luna.pp:PatchStr(code, line_start, line_start, "\n"..line_indent.."end\n")

              break
            end

            line_start = code:find("\n", line_start + 1)
          end
        end
      end
    end

    s, e = code:find("if[%Z]-then", e)
  end

  return code
end

-- Implicit returns
local function return_implicit(code)
  for k, v in ipairs(_CONTEXTS) do
    if (!v[1]:trim():trim("\t"):starts("function")) then continue end

    local orig_len = code:len()
    local lines = string.explode("\n", v[1])

    for i = #lines, 1, -1 do
      local line = lines[i]

      if (!line:find("return")) then
        if (line:find("function")) then
          local bfr, iu = "", nil

          for i2 = #line, 1, -1 do
            local v2 = line[i2]

            if (iu) then
              if (v2 == iu) then
                iu = nil
              end

              continue
            end

            if (v2 == "'" or v2 == "\"") then iu = v2 continue end
            if (v2 == ")") then iu = "(" continue end
            if ((bfr:reverse() == "end" or bfr == "") and v2 == " ") then bfr = "" continue end
            if (v2 == " ") then
              lines[i] = line:sub(1, i2).." return "..line:sub(i2 + 1, line:len())

              break
            end

            bfr = bfr..v2
          end

          break
        elseif (!line:find("end")) then
          lines[i] = line:gsub("([%s]*)([^%z]+)%s*", "%1return %2")

          break
        end
      else
        break
      end
    end

    code = luna.pp:PatchStr(code, v[2], v[3], table.concat(lines, "\n"))
    luna.pp:OffsetContexts(v[3], code:len() - orig_len)
  end

  return code
end

luna.pp:AddProcessor("logic", function(code)
  // ? in function names
  code = code:gsub("([%w%d_]+)[?]+([%s\n%()])","%1__bool%2")
  code = save_strings(code)

  local no_parse = {}
  local i = 1

  code = code:gsub("\3\4([%Z]+)\4\3", function(a)
    no_parse[i] = a
    i = i + 1

    return "\2"..(i - 1).."\2"
  end)

  code = fix_conditions(code)
  code = indent_blocks(code)

  code = hook.Run("luna_compiler_logic_fixed", code) or code

  code = fix_brackets(code)
  _CONTEXTS = luna.pp:GetContexts(code)
  code = return_implicit(code)

  for k, v in ipairs(no_parse) do
    code = code:gsub("\2"..k.."\2", v)
  end

  code = restore_strings(code)

  return code
end)