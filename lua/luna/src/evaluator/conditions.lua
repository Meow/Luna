local reading = false
local read_buffer = nil
local last_token = nil

function read_condition(token, level, tokens, obj, pos)
  if reading then
    if reading == 'cond' and (token != '\n' or last_token == 'or' or last_token == 'and' or last_token == ',') then
      push_lex_token(read_buffer, unpack(obj))

      last_token = token

      return
    elseif reading == 'name' and (obj[2] == TK_IDENTIFIER or token == '.' or token == ':') then
      push_lex_token(read_buffer, unpack(obj))

      return
    else
      if reading == 'cond' then
        level.cond = read_buffer
      elseif reading == 'name' then
        level.name = read_buffer
      end
  
      reading = false
      read_buffer = nil
      last_token = nil
    end
  end

  if level.logic and !level.cond then
    reading = 'cond'
    read_buffer = {}
  elseif level.def and !level.name then
    reading = 'name'
    read_buffer = {}
  end

  if read_buffer then
    push_lex_token(read_buffer, unpack(obj))

    return
  end
end
