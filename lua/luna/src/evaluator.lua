local group_closers = {
  ['('] = ')', [')'] = '(',
  ['['] = ']', [']'] = '[',
  ['{'] = '}', ['}'] = '{'
}

local conditionals = {
  ['if'] = true, ['elsif'] = true, ['case'] = true,
  ['switch'] = true
}

local read_name = {
  ['func'] = true, ['class'] = true, ['namespace'] = true
}

function _read_tk(tokens, pos, direction)
  direction = direction or 1
  local i = direction
  local nxt = tokens[pos + i]

  if nxt then
    local tk, type = nxt[1], nxt[2]
    local group = group_closers[tk]

    if type == TK_IDENTIFIER or type == TK_LITERAL or group then
      if !group then
        return nxt
      else
        local tks = {is_group = true}

        table.insert(tks, {GROUP_START})
        table.insert(tks, nxt)

        while true do
          i = i + direction
          nxt = tokens[pos + i]

          if i < 1 or i > #tokens then return false end
          
          table.insert(tks, nxt)

          if (group_closers[nxt[1]]) then
            break
          end
        end

        table.insert(tks, {GROUP_START})

        return tks
      end
    end
  else
    return false
  end
end

function _insert_tk(where, what)
  if what then
    if what.is_group then
      for k, v in pairs(what) do
        if isnumber(k) then
          push_lex_token(where, v[1], v[2], v[3])
        end
      end
    else
      push_lex_token(where, what[1], what[2], what[3])
    end
  end
end

function push_lex_token(where, ...)
  table.insert(where, {...})
end

function build_lex_tree(tokens)
  local tree = {}
  local top_level, current_level = nil, tree
  local i = 0

  -- Put an end-of-file separator at the very end
  table.insert(tokens, {nil, OP_eof})

  for k, v in ipairs(tokens) do
    local token, type, string_pos = v[1], v[2], v[3]

    if !token or !type or type == TK_NONE then continue end
    if !DEBUG and type == TK_COMMENT then continue end -- do not include comments in production mode

    if type == TK_KEYWORD then
      if CONTEXT_OPENERS[token] then
        i = i + 1

        if token == 'elsif' or token == 'else' or token == 'case' then
          if top_level and current_level.id == top_level.id then
            top_level = nil
          end

          current_level.no_end = true
          current_level = current_level.previous_level or tree

          table.insert(current_level, {
            previous_level = current_level,
            tk = token
          })
        else
          table.insert(current_level, {
            previous_level = current_level,
            tk = token
          })
        end

        current_level = current_level[#current_level]
        current_level.id = i
        current_level.logic = conditionals[token]
        current_level.def = read_name[token]

        if !top_level then
          top_level = current_level
        end
      elseif token == 'end' then
        if top_level and current_level.id == top_level.id then
          top_level = nil
        end

        current_level.put_end = true

        current_level = current_level.previous_level or tree
      else
        current_level = current_level or tree

        local error, severity = process_token(token, current_level, tokens, v, k)

        if isstring(error) then
          throw_error(error, severity or ERROR_CRITICAL, string_pos)
        end
      end
    else
      current_level = current_level or tree

      local error, severity = process_token(token, current_level, tokens, v, k)

      if isstring(error) then
        throw_error(error, severity or ERROR_CRITICAL, string_pos)
      end
    end

    if top_level then
      throw_error('Unclosed statement', ERROR_CRITICAL, -1)
    end
  end

  return tree
end
