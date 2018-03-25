luna.minifier = luna.minifier or {}

local function patch_str(str, start, endpos, replacement)
	return (start > 1 and str:sub(1, start - 1) or "")..replacement..str:sub(endpos + 1, str:len())
end

-- Because if we replace those then we can spare some extra spaces
local replaceable = {
  ["([^%w])or([^%w])"] = "%1||%2",
  ["([^%w])and([^%w])"] = "%1&&%2",
  ["\n"] = " ",
  ["\t"] = " ",
  ["%.%."] = "+",
  ["%.%+"] = "...", ["%+%."] = "...",
  ["([^%w])not "] = "%1!",
  ["([^%w])false([^%w])"] = "%1!0%2",
  ["([^%w])true([^%w])"] = "%1!!0%2"
}

-- All minifiable operators that shouldn't have leading or trailing spaces.
local minifiable = {
  "==", "=", ">=", "!=", "~=", "<=",
  "&&", "||", "%(", "%)", "{", "}", "%[", "%]",
  "%+", "%-", "/", "%*", ">", "<", "%.",
  ":", "#", "%^", "%%", ",", "\1", "!"
}

-- Characters that can be removed entirely
local removable = {
  ";", "\r"
}

-- That's where we store strings, because we shouldn't be minifying those.
local strings_storage = {}

-- stolen from string interp code lmao
function save_strings(code)
  local str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1
  local i, si = 0, 0
  local skip = 0

  strings_storage = {}

  while (i < code:len()) do
    i = i + 1

    if (skip > 0) then
      skip = skip - 1

      continue
    end

    local v = code:sub(i, i)

    if (str_open) then
      if (v == "\\") then
        skip = 1
      end

      if (v != close_char) then
        continue
      elseif (code:sub(i, i + close_seq:len() - 1) == close_seq) then
        si = si + 1
        strings_storage[si] = code:sub(open_pos, i + close_seq:len() - 1):gsub("/ /", "//")
        local new_code = patch_str(code, open_pos, i + close_seq:len() - 1, "\1"..si.."\1")

        i = i - (code:len() - new_code:len())

        code = new_code

        -- reset
        str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1

        continue
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

  return code
end

-- DRY.. where are you...
function sanitize_strings(code)
  local str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1
  local i = 0
  local skip = 0

  strings_storage = {}

  while (i < code:len()) do
    i = i + 1

    if (skip > 0) then
      skip = skip - 1

      continue
    end

    local v = code:sub(i, i)

    if (str_open) then
      if (v == "\\") then
        skip = 1
      end

      if (v != close_char) then
        continue
      elseif (code:sub(i, i + close_seq:len() - 1) == close_seq) then
        local str = code:sub(open_pos, i + close_seq:len() - 1):gsub("//", "/ /")

        code = patch_str(code, open_pos, i + close_seq:len() - 1, str)

        -- reset
        str_open, open_char, close_char, close_seq, open_seq, open_pos = false, "", "", "", "", -1

        continue
      end
    end

    if (!str_open) then
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
  end

  return code
end

function restore_strings(code)
  code = code:gsub("\1([%d]+)\1", function(k)
    return strings_storage[tonumber(k)]
  end)

  return code
end

function luna.minifier:Minify(code, should_debug)
  local old_len = code:len()

  code = sanitize_strings(code)

  -- Strip comments.
  code = code:gsub("/%*[^%z]-*/", "")
  code = code:gsub("%-%-%[%[[^%z]-%]%]", "")
  code = code:gsub("//[^\n]+", "")
  code = code:gsub("%-%-[^\n]+", "")

  code = save_strings(code)

  -- Remove garbage spaces and tabs.
  while (code:find("%s\n")) do
    code = code:gsub("%s\n", "\n")
  end

  -- Garbage spaces
  code = code:gsub("[%s]+", " ")

  -- Remove garbage newlines.
  while (code:find("\n\n")) do
    code = code:gsub("\n\n", "\n")
  end

  for k, v in ipairs(removable) do
    code = code:gsub(v, "")
  end

  for k, v in pairs(replaceable) do
    code = code:gsub(k, v)
  end

  -- Because apparently once is not enough...
  for i = 1, 10 do
    for k, v in ipairs(minifiable) do
      code = code:gsub("[%s]*"..v.."[%s]*", v)
    end
  end

  code = code:trim():trim("\t"):trim("\n"):gsub("%-%-", "")
  code = restore_strings(code)

  if (should_debug) then
    print("Minified: "..old_len.." -> "..code:len())
    print(math.ceil(100 - code:len() / old_len * 100).."% reduction")
  end

  return code
end