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
        o["#1"](nobj, ...)
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
        if bc.base_class and (bc.class_name != bc.base_class.class_name) then
          bc = bc.base_class
        else
          has_bc = false
        end
      end
      if o["#1"] then
        o["#1"](nobj, ...)
      end
      nobj.IsValid = function(ob) return true end
      nobj.valid = nobj.IsValid
      return nobj
    end,
    class_name = "#1",
    base_class = _G["#2"]
  }
  _G["#1"] = _class
#3
  local _base = _G["#2"]
  if istable(_base) then
    local copy = table.Copy(_base)
    table.safe_merge(copy, _G["#1"])
    if isfunction(_base.extended) then
      local s, v = pcall(_base.extended, _base, copy)
      if !s then
        ErrorNoHalt("'extended' class hook has failed to run!\n"..tostring(v).."\n")
      end
    end
    _G["#1"] = copy
  else
    ErrorNoHalt("#2 is not a valid class!\n")
  end
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
        o["#1"](nobj, ...)
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
        if bc.base_class and (bc.class_name != bc.base_class.class_name) then
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
  _G["#1"] = _class
#3
  local _base = _G["#2"]
  if istable(_base) then
    local copy = table.Copy(_base)
    table.safe_merge(_G["#1"], copy)
    if isfunction(_G["#1"].extended) then
      local s, v = pcall(_G["#1"].extended, _G["#1"], copy)
      if !s then
        ErrorNoHalt("'extended' class hook has failed to run!\n"..tostring(v).."\n")
      end
    end
  else
    ErrorNoHalt("#2 is not a valid class!\n")
  end
end
]]

local function process_definition(code)
  local s, e, class_name = code:find("class%s+([%w_]+)")

  while (s) do
    if (s - 1 == 0 or code:sub(s - 1, s - 1):match("[%s\n]")) then
      line = code:sub(e + 1, code:find("\n", e + 1)):trim():trim("\n")

      if (#line <= 0) then line = class_name end

      if (line and #line > 0) then
        local class_end, real_end = luna.util.FindLogicClosure(code, e, 1)

        if (!real_end) then
          parser_error("'end' not found for class", s, ERROR_CRITICAL)

          return code
        end

        local code_block = code:sub(code:find("\n", e + 1) + 1, class_end - 1)

        -- Context-aware member assignment
        local function_contexts = {}

        local function _find_func_ctx()
          function_contexts = {}
          local strt, fnend, fn_name = code_block:find("function%s+([%w_]+)")

          while (strt) do
            local func_end, real_func_end = luna.util.FindLogicClosure(code, fnend, 1)

            if (real_func_end) then
              table.insert(function_contexts, {strt, real_func_end, fn_name})
            else
              parser_error("'end' not found for function!", strt, ERROR_CRITICAL)

              return code
            end

            strt, fnend, fn_name = code_block:find("function%s+([%w_]+)", real_func_end)
          end
        end

        local _check_ctx = function(pos)
          for k, v in ipairs(function_contexts) do
            if pos >= v[1] and pos <= v[2] then
              return v
            end
          end

          return false
        end

        _find_func_ctx()

        -- Locals should be class members
        local lcstrt, lcend, lc_name = code_block:find("local%s+([%w_]+)")

        while (lcstrt) do
          if (!_check_ctx(lcstrt)) then
            local newname = class_name.."."..lc_name

            code_block = luna.pp:PatchStr(code_block, lcstrt, lcend, newname)
            lcend = lcstrt + newname:len()
          end

          lcstrt, lcend, lc_name = code_block:find("local%s+([%w_]+)", lcend)
        end

        _find_func_ctx()

        -- super
        local supstrt, supend, arg_list = code_block:find("super([^\n]*)")

        while (supstrt) do
          local fnctx = _check_ctx(supstrt)

          if (fnctx and code_block[supend + 1]:match("[%s%(]") and code_block[supstrt - 1]:match("[^%w_]")) then
            arg_list = arg_list:trim()
            local newcond = "pcall((self.base_class or {})."..fnctx[3].." and (self.base_class or {})."..fnctx[3]..", self"..(#arg_list > 0 and ", "..arg_list or "")..")"

            code_block = luna.pp:PatchStr(code_block, supstrt, supend, newcond)
            supend = supstrt + newcond:len()
          end

          supstrt, supend, arg_list = code_block:find("super([^\n]*)", supend)
        end

        -- member functions
        code_block = code_block:gsub("function%s+([%w_]+)", "function "..class_name..":%1")

        -- class extended
        if (line:find("<") or line:find(">")) then
          local extend_regular = line:find("<")
          local extend_char = extend_regular and "<" or ">"
          local base_class_name = line:sub(line:find(extend_char) + 1, #line):trim()
          local class_code = extend_regular and class_base_extend or class_base_extend_reverse

          class_code = class_code:gsub("#1", class_name):gsub("#2", base_class_name):gsub("#3", code_block)
          code = luna.pp:PatchStr(code, s, real_end, class_code)

          e = s + class_code:len()
        else -- regular class
          local class_code = class_base

          class_code = class_code:gsub("#1", class_name):gsub("#3", code_block)
          code = luna.pp:PatchStr(code, s, real_end, class_code)

          e = s + class_code:len()
        end
      end
    end

    s, e, class_name = code:find("class%s+([%w_]+)", e)
  end

  return code
end

local function process_instantiation(code)
  return code:gsub("new%s+([%w_]+)", "%1:new")
end

luna.pp:AddProcessor("oop", function(code)
  code = save_strings(code, true)
  code = code:gsub("this%.", "self."):gsub("this:", "self:"):gsub("([%s\n]?)this([%s\n]?)", "%1self%2")
  code = process_definition(code)
  code = process_instantiation(code)
  code = restore_strings(code)

  return code
end)
