linter = linter or {}
linter.checkers = linter.checkers or {}
linter.errors = linter.errors or {}

local current_module = nil
local current_urgency = nil

LINT_OK = 0
LINT_MINOR = 1
LINT_WARNING = 2
LINT_CRITICAL = 3
LINT_ERROR = 4

local color_match = {
  [LINT_OK] = COLOR_GREEN,
  [LINT_MINOR] = COLOR_YELLOW,
  [LINT_WARNING] = COLOR_CYAN,
  [LINT_CRITICAL] = COLOR_RED,
  [LINT_ERROR] = COLOR_PINK
}

function linter.add_check(name, urgency, fn)
  linter.checkers[name] = {
    name = name,
    callback = fn,
    urgency = urgency
  }
end

function linter.push_error(message, snippet, where)
  if (snippet and snippet:len() > 48) then
    local before, after, spot = snippet:sub(1, where - 1), snippet:sub(where + 1, snippet:len()), snippet[where]
    local dots_b, dots_a = false, false

    if (#before > 21) then
      where = where - (before:len() - 21) + 4
      before = before:sub(before:len() - 21, before:len())
      dots_b = true
    end

    if (#after > 20) then
      after = after:sub(1, 20)
      dots_a = true
    end

    snippet = (dots_b and "..." or "")..before..spot..after..(dots_a and "..." or "")
  end
  
  table.insert(linter.errors, {where = where, snippet = snippet, module = current_module, urgency = current_urgency, msg = message})
end

function linter.check(code)
  linter.errors = {}

  for k, v in pairs(linter.checkers) do
    current_module = v.name
    current_urgency = v.urgency

    v.callback(code)
  end

  MsgC(#linter.errors > 0 and COLOR_YELLOW or COLOR_GREEN, "Linter done!")

  if (#linter.errors > 0) then
    MsgC(COLOR_YELLOW, " ]:C\n")

    for k, v in ipairs(linter.errors) do
      MsgC(color_match[v.urgency], v.module..": "..v.msg.."\n")

      if (v.where) then
        MsgC(COLOR_LIGHT_GREY, v.snippet.."\n")
        MsgC(COLOR_WHITE, string.rep("-", (v.where > 42 and v.where - 7 or v.where - 2))..(v.where > 42 and " HERE ^ " or " ^ HERE ")..string.rep("-", 48 - v.where).."\n")
      end
    end
  else
    MsgC(COLOR_GREEN, "\nAll good ^_^\n")
  end
end

linter.add_check("Varargs", LINT_ERROR, function(code)
  local lines = code:split("\n")

  for k, v in ipairs(lines) do
    local s, e = v:find("%.%.%.")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Varargs are only supported as splat arguments!", v, s)
      s, e = v:find("%.%.%.", e + 1)
    end
  end
end)

linter.add_check("Commas", LINT_MINOR, function(code)
  local lines = code:split("\n")

  for k, v in ipairs(lines) do
    local s, e = v:find(",[^%s]")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Missing space after comma.", v, s)
      s, e = v:find(",[^%s]", e + 1)
    end
  end

  for k, v in ipairs(lines) do
    local s, e = v:find("[%s],")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Do not put spaces before punctuation.", v, s)
      s, e = v:find("[%s],", e + 1)
    end
  end
end)

linter.add_check("Spaces", LINT_MINOR, function(code)
  local lines = code:split("\n")

  for k, v in ipairs(lines) do
    local s, e = v:find("%(%s")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Do not put spaces after the parentheses.", v, e)
      s, e = v:find("%(%s", e + 1)
    end
  end

  for k, v in ipairs(lines) do
    local s, e = v:find("%s%)")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Do not put spaces before the parentheses.", v, s)
      s, e = v:find("%s%)", e + 1)
    end
  end

  for k, v in ipairs(lines) do
    local s, e = v:find("%[%s")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Do not put spaces after the brackets.", v, e)
      s, e = v:find("%[%s", e + 1)
    end
  end

  for k, v in ipairs(lines) do
    local s, e = v:find("%s%]")

    while e and e <= v:len() do
      linter.push_error("Line "..k.." - Do not put spaces before the brackets.", v, s)
      s, e = v:find("%s%]", e + 1)
    end
  end
end)
