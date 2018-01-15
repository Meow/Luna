luna.namespaces = luna.namespaces or {}
local namespaces = {}

function luna.namespaces:Resolve(code)
  code = code:gsub("::", "__")

  local s, e, t = code:find("namespace%s*([%w_]+)%s*\n")

  while (s) do
    local npr = t.."__"
    namespaces[t] = npr

    local closure, closure_end = luna.util.FindLogicClosure(code, e, 1)

    if (closure != -1) then
      local block = code:sub(e, closure - 1)

      if (block:find("namespace%s*([%w_]+)%s*\n")) then
        block = self:Resolve(block)
      end

      block = block:gsub("function%s*([%w_]+)", "function "..npr.."%1")
      block = hook.Run("luna_namespace_apply", code, npr, t) or block
      block = block:gsub("\n"..luna.pp:Get("i"), "\n")

      code = luna.pp:PatchStr(code, s, closure_end, block)
    else
      error("Closure not found for namespace!\n")
    end

    s, e, t = code:find("namespace%s*([%w_]+)%s*\n", e)
  end

  return code
end

hook.Add("luna_compiler_logic_fixed", "luna_namespacing", function(code)
  return luna.namespaces:Resolve(code)
end)