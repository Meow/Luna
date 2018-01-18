local function parse_yield(code, obj)
  return code
end

local function process_yield(code, obj)
  return code
end

local function parse_splat(code, obj)
  local block = code:sub(obj.context_start, obj.context_end)
  local s, e = block:find("%*")

  if (s) then
    local ending = block:find(",", s) or block:find("%)", s)
    local arg_end = block:find("%)", s)
    local arg = block:sub(s + 1, ending - 1)

    if (arg_end == ending) then
      ending = ending - 1
    end

    -- beginning of arg list
    if (block:match("%(%s*%*")) then
      obj.splat_pos = 0
      obj.end_args = #(block:sub(block:find("%(%s*%*"), block:find("%)") - 1):split(",") or {}) - 1
    elseif (block:match(",%s*%*[%w_]+%s*,")) then -- middle
      obj.splat_pos = 1

      local before, after = block:sub(block:find("%(") + 1, block:find(",%s*%*[%w_]+%s*,") - 1),
                            block:sub(block:find(",%s*%*[%w_]+%s*,") + 1, block:find("%)") - 1)

      obj.start_args = #before:split(",")
      obj.end_args = #after:split(",")
    else -- end of arg list
      obj.splat_pos = 2
      obj.start_args = #(block:sub(1, block:find("%)") - 1):split(",") or {}) - 1
    end

    block = luna.pp:PatchStr(block, arg_end, arg_end, (obj.splat_pos != 2 and "," or "")..arg..")")
    block = luna.pp:PatchStr(block, s, ending, "")
    code = luna.pp:PatchStr(code, obj.context_start, obj.context_end, block)
  end

  return code
end

local function process_splat(code, obj)
  local s, e = code:find(obj.name.."[%s%(]")

  while (s) do
    if (s >= obj.context_start and s <= obj.context_end) then
      s, e = code:find(obj.name.."[%s%(]", e)

      continue
    end

    local args, start, end_pos, end_char = read_arguments(code, e, nil, true)

    if (args) then
      local splat = "{"

      args = args:gsub("([%w_]+):%s*([^,\n]+)", function(name, value, ending)
        splat = splat.."['"..name.."'] = "..value..","

        return ""
      end)

      args = args:gsub(",[%s]*", ",")

      while (args:find(",,")) do
        args = args:gsub(",,", ",")
      end

      local exploded = args:split(",")
      local rs, re = obj.start_args or 0, obj.end_args or 0
      local _rs, _re, _spt = {}, {}, {}
      local i = 0

      for k, v in ipairs(exploded) do
        if (!v:find(":")) then
          if (rs > 0) then
            table.insert(_rs, v)
            rs = rs - 1
          elseif (re > 0 and re <= (#exploded - k)) then
            table.insert(_spt, v)  
          else
            table.insert(_re, v)
          end
        end
      end

      splat = splat..table.concat(_spt, ",")
      splat = splat:trim(",").."}"

      local new_args = table.concat(_rs, ",")..
        (#_re > 0 and "," or "")..
        table.concat(_re, ",")..
        splat

      code = luna.pp:PatchStr(code, start, end_pos, new_args)
    end

    s, e = code:find(obj.name.."[%s%(]", e)
  end

  return code
end

hook.Add("luna_globals_info_gathered", "luna_splat_yield", function(obj)
  local code = obj.code

  for k, v in pairs(_GLOBALS) do
    if (v.is_func) then
      if (v.path == CURRENT_PATH) then
        if (v.splattable) then
          code = parse_splat(code, v) or code
        end

        if (v.yieldable) then
          code = parse_yield(code, v) or code
        end
      end

      code = process_splat(code, v) or code
    end
  end

  obj:set(code)
end)