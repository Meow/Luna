luna.pp:AddProcessor("default_args", function(code)
  local s, e, a, b = code:find("function%s([%w_%.:]+)%s*%(([^%)]+)%)")

  while (s) do
    if (a and b) then
      if (b:find("=")) then
        local def_args = {}
        local buf, val = "", ""
        local ret = ""
        local str
        local rv = false

        for i = 1, #b do
          local v = b[i]

          if (str) then
            if (str == v) then
              str = false

              def_args[buf] = val
            end

            val = val..v

            continue
          end

          if (v == "=") then
            rv = true

            continue
          end

          if ((!rv or v == ",") and v != " ") then
            ret = ret..v
          end

          if (rv and v == "'" or v =="\"") then
            str = v
            val = val..v

            continue
          end

          if (v == "," or v == ")" or v == "\n") then
            if (rv) then def_args[buf] = val end

            rv = false
            buf = ""
            val = ""

            continue
          end

          if (v == " ") then continue end
          if (!rv) then buf = buf..v else val = val..v end
        end

        if (val != "") then
          def_args[buf] = val
        end

        local patched = ""

        for k, v in pairs(def_args) do
          patched = patched..luna.pp:Get("i").."if("..k.."==nil)then "..k.."="..v.." end\n"
        end

        local olen = code:len()

        code = luna.pp:PatchStr(code, e, e, ")\n"..patched)
        code = luna.pp:PatchStr(code, s, e, "function "..a.."("..ret..")")

        e = e + (code:len() - olen)
      end
    end

    s, e, a, b = code:find("function%s([%w_%.:]+)%s*%(([^%)]+)%)", e)
  end

	return code
end)