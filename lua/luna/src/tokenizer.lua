function tokenize(code)
  local buf = ''
  local skip = 0
  local reading_string, string_opener, string_start = false, '', -1
  local reading_comment, comment_multiline = false, false
  local tokens = {}
  local i = 1

  local function _next(offset)
    return code[i + 1 + ((offset or 1) - 1)]
  end

  local function _prev(offset)
    return code[i - 1 - ((offset or 1) - 1)]
  end

  local function _push(...)
    local args = {...}
    args[3] = i -- for debug
    table.insert(tokens, args)
  end

  local function _flush_buf()
    if (buf:trim() != '') then
      if tonumber(buf) or LITERAL_MATCH[buf] then
        _push(buf:trim(), LITERAL_MATCH[buf])
      elseif KEYWORD_MATCH[buf] then
        _push(buf:trim(), KEYWORD_MATCH[buf])
      else
        _push(buf:trim(), IDENTIFIER)
      end
    end

    buf = ''
  end

  for i = 1, #code do
    if (skip > 0) then
      skip = skip - 1

      continue
    end

    local v = code[i]

    if reading_string then
      if v == '\n' and string_opener != '"' and _prev() != '\\' then
        throw_error('Unclosed string', ERROR_CRITICAL, string_start)
        return
      end

      if v == string_opener and _prev() != '\\' then
        _push(buf..v, (string_opener == '"' and LIT_STRINGD or LIT_STRING))
        buf, reading_string, string_opener, string_start = '', false, '', -1
        continue
      else
        buf = buf..v
        continue
      end
    elseif reading_comment then
      if (comment_multiline and v == '*' and code[i + 1] == '/') or (!comment_multiline and v == '\n') then
        _push(buf..(code:sub(i, i + (comment_multiline and 1 or 0))), COMMENT)
        reading_comment = false
        comment_multiline = false
        buf = ''
        continue
      end

      buf = buf..v

      continue
    end

    if v == '"' or v == '\'' then
      reading_string = true
      buf = v
      string_opener = v
      string_start = i
      continue
    elseif v == '/' and (code[i + 1] == '/' or code[i + 1] == '*') then
      reading_comment = true
      comment_multiline = (code[i + 1] == '*')
      buf = v
      continue
    end

    local next = code[i + 1]
    local prev = code[i - 1]

    if SEPARATOR_MATCH[v] then
      if (buf != '') then
        if v == '.' and tonumber(buf) and tonumber(next) then
          buf = buf..v
          continue
        end

        _flush_buf()
      end

      if (v == '.' and next == '.') then
        if (_next(2) == '=') then -- ... and ..=
          _push(v..next.._next(2), OP_concateq)
          skip = 2
        elseif (_next(2) != '.') then
          _push('..', OP_concat)
          skip = 1
        end

        continue
      end

      if v == ':' and next == ':' then
        _push(v..next, SEP_DOUBLE)
        skip = 1
        continue
      end

      _push(v, SEPARATOR_MATCH[v])

      continue
    end

    if v == '+' or v == '-' or v == '>' or v == '<' or v == '%' or
      v == '*' or v == '/' or v == '&' or v == '|' or v == '^' or
      v == '@' or v == '#' then
      if (v == '|' or v == '&' or v == '>' or v == '<' or v == '=' or v == '+' or v == '-') and next == v then
        _push(v..next, TOKEN_MATCH[v..next])
        skip = 1
        continue
      end

      if (v == '>' or v == '<') and next == v and _next(2) == '=' then
        _push(v..next..'=', TOKEN_MATCH[v..next..'='])
        skip = 2
        continue
      end

      if next == '=' then
        _push(v..next, TOKEN_MATCH[v..next])
        skip = 1
        continue
      end

      _push(v, TOKEN_MATCH[v])

      continue
    end

    if v == '?' or v == '!' then
      if (next == ' ' or next == '\n') and prev:match('[%w_]') then
        buf = buf..v
      elseif v == '!' and next == '=' then
        _push(v..next, TOKEN_MATCH[v..next])
        skip = 1
      else
        _push(v, TOKEN_MATCH[v])
      end

      continue
    end

    if v == ' ' and buf != '' then
      _flush_buf()

      continue
    elseif v == '=' then
      if buf != '' then
        if KEYWORD_MATCH[buf] then
          _push(buf..v, KEYWORD_MATCH[buf])
          buf = ''
          continue
        else
          _flush_buf()

          _push(v, TOKEN_MATCH[v])
        end
      elseif next == '=' then
        _push(v..next, TOKEN_MATCH[v..next])
        skip = 1
      else
        _push(v, TOKEN_MATCH[v])
      end

      continue
    end

    buf = buf..v
  end

  return tokens
end
