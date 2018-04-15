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
        _push(buf..v, TK_LITERAL)
        buf, reading_string, string_opener, string_start = '', false, '', -1
        continue
      else
        buf = buf..v
        continue
      end
    elseif reading_comment then
      if (comment_multiline and v == '*' and code[i + 1] == '/') or (!comment_multiline and v == '\n') then
        _push(buf..(code:sub(i, i + (comment_multiline and 1 or 0))), TK_COMMENT)
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

    if v == ',' or v == '.' or v == '(' or v == ')' or
      v == '{' or v == '}' or v == '[' or v == ']' or
      v == ';' or v == '\n' or v == ':' then
      if (buf != '') then
        if v == '.' and tonumber(buf) and tonumber(next) then
          buf = buf..v
          continue
        end

        if (buf:trim() != '') then
          if tonumber(buf) or LUNA_LITERALS[buf] then
            _push(buf:trim(), TK_LITERAL)
          elseif LUNA_KEYWORDS[buf] then
            _push(buf:trim(), TK_KEYWORD)
          else
            _push(buf:trim(), TK_IDENTIFIER)
          end
        end

        buf = ''
      end

      if (v == '.' and next == '.') then
        if (_next(2) == '.' or _next(2) == '=') then -- ... and ..=
          _push(v..next.._next(2), TK_LITERAL)
          skip = 2
        else
          _push('..', TK_OPERATOR)
          skip = 1
        end

        continue
      end

      if v == ':' and next == ':' then
        _push(v..next, TK_SEPARATOR)
        skip = 1
        continue
      end

      _push(v, TK_SEPARATOR)

      continue
    end

    if v == '+' or v == '-' or v == '>' or v == '<' or v == '%' or
      v == '*' or v == '/' or v == '&' or v == '|' or v == '^' or
      v == '@' or v == '#' then
      if (v == '|' or v == '&' or v == '>' or v == '<' or v == '=' or v == '+' or v == '-') and next == v then
        _push(v..next, TK_OPERATOR)
        skip = 1
        continue
      end

      if (v == '>' or v == '<') and next == v and _next(2) == '=' then
        _push(v..next..'=', TK_OPERATOR)
        skip = 2
        continue
      end

      if next == '=' then
        _push(v..next, TK_OPERATOR)
        skip = 1
        continue
      end

      _push(v, TK_OPERATOR)

      continue
    end

    if v == '?' or v == '!' then
      if (next == ' ' or next == '\n') and prev:match('[%w_]') then
        buf = buf..v
      elseif v == '!' and next == '=' then
        _push(v..next, TK_OPERATOR)
        skip = 1
      else
        _push(v, TK_OPERATOR)
      end

      continue
    end

    if v == ' ' and buf != '' then
      if tonumber(buf) or LUNA_LITERALS[buf] then
        _push(buf:trim(), TK_LITERAL)
      elseif LUNA_KEYWORDS[buf] then
        _push(buf:trim(), TK_KEYWORD)
      else
        if (buf:trim() != '') then
          _push(buf:trim(), TK_IDENTIFIER)
        end
      end

      buf = ''

      continue
    elseif v == '=' then
      if buf != '' then
        if LUNA_KEYWORDS[buf] then
          _push(buf..v, TK_OPERATOR)
          buf = ''
          continue
        else
          if tonumber(buf) or LUNA_LITERALS[buf] then
            _push(buf:trim(), TK_LITERAL)
          else
            if (buf:trim() != '') then
              _push(buf:trim(), TK_IDENTIFIER)
            end
          end

          buf = ''

          _push(v, TK_OPERATOR)
        end
      elseif next == '=' then
        _push(v..next, TK_OPERATOR)
        skip = 1
      else
        _push(v, TK_OPERATOR)
      end

      continue
    end

    buf = buf..v
  end

  return tokens
end
