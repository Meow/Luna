local blocked_arg_strings = {
  "end", "then", "in", "pairs", "pairs(", "ipairs", "ipairs("
}

local blocked_characters = {
  ["{"] = true, ["}"] = true, ["("] = true,
  [")"] = true, ["["] = true, ["]"] = true,
  ["."] = true, [","] = true, ["/"] = true,
  ["&"] = true, ["|"] = true, [":"] = true,
  ["})"] = true
}

local function fix_bracket_argumented_call(code, bracket_start)
  local arg_str, s, e, end_char = read_arguments(code, bracket_start)

  if (arg_str) then
    for k, v in ipairs(blocked_arg_strings) do
      if (arg_str:find("[^%w_]"..string.pattern_safe(v).."[^%w_]") or arg_str == v) then
        return code
      end
    end

    if (blocked_characters[arg_str] or !arg_str:find("[%w_]")) then
      return code
    end

    code = luna.pp:PatchStr(code, s, s, "(")
    code = luna.pp:PatchStr(code, e, e, ")"..end_char)
  end

  return code
end

local function is_str_function(str, parent)
  local obj = luna.util.FindTableVal(str, parent)

  if (isfunction(obj) or (istable(obj) and obj.is_func)) then
    return true
  elseif (!parent or parent == _G) then
    obj = _GLOBALS[str]

    if (istable(obj) and obj.type == "function") then
      return true
    end
  end

  return false
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
  code = code:gsub("([%w_]+)__dng([%s\n])", "%1__dng()%2")

  -- a.b / AWFUL HOTFIX
  code = code:gsub("([%w_]+)%.([%w_]+)%s+([^%z\n%s]*)", function(a, b, c)
    if (!LUA_OP_SYMBOLS[c] and !LUA_OPERATORS[c]) then
      if (is_str_function(a.."."..b)) then
        return a.."."..b.."()"..c
      end
    end
  end)

  -- ToDo: Check for variable
  code = code:gsub("([%w_]+)%.([%w_]+)\n", function(a, b)
    if (is_str_function(a.."."..b)) then
      return a.."."..b.."()\n"
    end
  end)

  return code
end

-- Fix missing then
local function fix_conditions(code)
  local s, e = code:find("if")

  while (s) do
    local args, st, en, en_char = read_arguments(code, e + 1, true)
  
    if (args and !args:ends("then") and !is_next_statement(code, "then", en + 1)) then
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

-- Implicit returns
local function return_implicit(code)
  for k, v in ipairs(_CONTEXTS) do
    if (!v[1]:trim():trim("\t"):starts("function")) then continue end

    local orig_len = code:len()
    local lines = string.explode("\n", v[1])

    for i = #lines, 1, -1 do
      local line = lines[i]

      if (!line:find("return")) then
        if (line:find("function") and #lines < 2) then
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
        elseif (!line:find("[^%w]end") and line != "end" and !line:find("=[^=]") and !line:find("[}%)]") and i != 1) then
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
  // ? and ! in function names
  code = code:gsub("([%w_]+)[!]+([%s\n%)])","%1__dng%2")
  code = code:gsub("([%w_]+)[?]+([%s\n%()])","%1__bool%2")
  code = save_strings(code)

  local no_parse = {}
  local i = 1

  code = code:gsub("\3\4([%Z]+)\4\3", function(a)
    no_parse[i] = a
    i = i + 1

    return "\2"..(i - 1).."\2"
  end)

  code = fix_conditions(code)

  local cobj = {code = code, set = function(self, new)
    self.code = new or self.code
  end}

  hook.Call("luna_compiler_logic_fixed", cobj)

  code = cobj.code

  code = fix_brackets(code)
  _CONTEXTS = luna.pp:GetContexts(code)
  code = return_implicit(code)

  for k, v in ipairs(no_parse) do
    code = code:gsub("\2"..k.."\2", v)
  end

  code = restore_strings(code)

  return code
end)
