luna.namespaces = luna.namespaces or {}
local namespaces = {}

function luna.namespaces:Resolve(code)
  local s, e, t = code:find("namespace%s*([%w_%.]+)%s*\n")

  while (s) do
    t = t:gsub("%.", "__")
    namespaces[t] = t

    local closure, closure_end = luna.util.FindLogicClosure(code, e, 1)

    if (closure != -1) then
      local block = code:sub(e, closure - 1)

      if (block:find("namespace%s*([%w_]+)%s*\n")) then
        block = self:Resolve(block)
      end

      block = block:gsub("function%s*([%w_%.]+)", "function "..t.."__%1")
      block = block:gsub("([%w_%.]+)%s*=%s*([^\n;]+)", t.."__%1 = (%2)\n")
      block = hook.Run("luna_namespace_apply", code, t.."__", t) or block
      block = block:gsub("\n"..luna.pp:Get("i"), "\n")

      code = luna.pp:PatchStr(code, s, closure_end, block)
    else
      error("Closure not found for namespace!\n")
    end

    s, e, t = code:find("namespace%s*([%w_%.]+)%s*\n", e)
  end

  for k, v in pairs(namespaces) do
    code = code:gsub(v.."%.", v.."__")
  end

  return code
end

hook.Add("luna_compiler_logic_fixed", "luna_namespacing", function(obj)
  obj:set(luna.namespaces:Resolve(obj.code))
end)