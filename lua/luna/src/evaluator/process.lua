-- Coordinate processors properly
function process_token(token, level, tokens, obj, pos)
  --print(obj[1] + '\t' + obj[2] + '\t' + obj[3])
  if read_condition(token, level, tokens, obj, pos) then
    return
  end

  local match = TOKEN_MATCH[token]
  local tks_buf = {}

  if match then
    --process_binop(match, token, level, tokens, pos)
    --process_unop(match, token, level, tokens, pos)
    --process_op(match, token, level, tokens, pos)
  end
end
