-- TODO
-- TODO
-- TODO

local classes = {}

-- No base class
local class_base = [[
do
  local _class = {
    new = function(o, ...)
      local nobj = {}
      setmetatable(nobj, o)
      table.safe_merge(nobj, o)
      if o["#1"] then
        local s, v = pcall(o["#1"], nobj, ...)
        if !s then
          ErrorNoHalt("[#1] Class constructor has failed to run!\n")
          ErrorNoHalt(v.."\n")
        end
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = nil
  }
  _G["#1"] = _class
  #3
end
]]

-- with base class
local class_base_extend = [[
do
  local _class = {
    new = function(o, ...)
      local nobj = {}
      setmetatable(nobj, o)
      table.safe_merge(nobj, o)
      local bc = o.base_class
      local has_bc = true
      while istable(bc) and has_bc do
        if isfunction(bc[bc.class_name]) then
          local s, v = pcall(bc[bc.class_name], nobj, ...)
          if !s then
            ErrorNoHalt("Base class constructor has failed to run!\n"..tostring(v).."\n")
          end
        end
        if bc.base_class and bc.class_name != bc.base_class.class_name then
          bc = bc.base_class
        else
          has_bc = false
        end
      end
      if o["#1"] then
        local s, v = pcall(o["#1"], nobj, ...)
        if (!s) then
          ErrorNoHalt("[#1] Class constructor has failed to run!\n")
          ErrorNoHalt(v.."\n")
        end
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = _G["#2"]
  }
  local _base = _G["#2"]
  if istable(_base) then
    local copy = table.Copy(_base)
    local merged = table.safe_merge(copy, _class)
    if isfunction(_base.extended) then
      local s, v = pcall(_base.extended, copy, merged)
      if !s then
        ErrorNoHalt("'extended' class hook has failed to run!\n"..tostring(v).."\n")
      end
    end
    _class = merged
  end
  _G["#1"] = _class
  #3
end
]]

-- with base class, reverse init
local class_base_extend_reverse = [[
do
  local _class = {
    new = function(o, ...)
      local nobj = {}
      setmetatable(nobj, o)
      table.safe_merge(nobj, o)
      if o["#1"] then
        local s, v = pcall(o["#1"], nobj, ...)
        if (!s) then
          ErrorNoHalt("[#1] Class constructor has failed to run!\n")
          ErrorNoHalt(v.."\n")
        end
      end
      local bc = o.base_class
      local has_bc = true
      while istable(bc) and has_bc do
        if isfunction(bc[bc.class_name]) then
          local s, v = pcall(bc[bc.class_name], nobj, ...)
          if !s then
            ErrorNoHalt("Base class constructor has failed to run!\n"..tostring(v).."\n")
          end
        end
        if bc.base_class and bc.class_name != bc.base_class.class_name then
          bc = bc.base_class
        else
          has_bc = false
        end
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = _G["#2"]
  }
  local _base = _G["#2"]
  if istable(_base) then
    local copy = table.Copy(_base)
    local merged = table.safe_merge(_class, copy)
    if isfunction(_class.extended) then
      local s, v = pcall(_class.extended, _class, merged)
      if !s then
        ErrorNoHalt("'extended' class hook has failed to run!\n"..tostring(v).."\n")
      end
    end
    _class = merged
  end
  _G["#1"] = _class
  #3
end
]]

local function process_definition(code)
  local s, e, classname = code:find("class%s+([%w_]+)")

  while (s) do
    if (code:sub(s - 1, s - 1) != "_") then
      line = code:sub(e + 1, code:find("\n", e + 1)):trim():trim("\n")

      if (#line <= 0) then line = classname end

      if (line and #line > 0) then
        local class_end, real_end = luna.util.FindLogicClosure(code, e, 1)

        if (!real_end) then
          parser_error("'end' not found for class", s, ERROR_CRITICAL)

          return code
        end

        local code_block = code:sub(code:find("\n", e + 1) + 1, class_end - 1)

        -- class extended
        if (line:find("<") or line:find(">")) then
          local extend_regular = line:find("<")
          local extend_char = extend_regular and "<" or ">"
          local class_name = line:sub(1, line:find(extend_char) - 1)
          local base_class_name = line:sub(line:find(extend_char) + 1, #line)
          local class_code = extend_regular and class_base_extend or class_base_extend_reverse

          code_block:gsub("function%s+([%w_]+)", "function "..class_name..":%1")
          class_code = class_code:gsub("#1", class_name):gsub("#2", base_class_name):gsub("#3", code_block)
          
          code = luna.pp:PatchStr(code, s, real_end, class_code)
        else -- regular class
          local class_name = line:trim():gsub("\n", "")
          local class_code = class_base

          code_block = code_block:gsub("function%s+([%w_]+)", "function "..class_name..":%1")

          class_code = class_code:gsub("#1", class_name):gsub("#3", code_block)

          code = luna.pp:PatchStr(code, s, real_end, class_code)
        end

        e = real_end
      end
    end

    s, e = code:find("class%s+[%w_]+", e)
  end

  return code
end

local function process_instantiation(code)
  return code
end

luna.pp:AddProcessor("oop", function(code)
  code = process_definition(code)
  code = process_instantiation(code)

  return code
end)
