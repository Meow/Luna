local binops = {
  [OP_eq] = true, [OP_assign] = true, [OP_pluseq] = true,
  [OP_minuseq] = true, [OP_diveq] = true, [OP_muleq] = true,
  [OP_modeq] = true, [OP_boreq] = true, [OP_oreq] = true, [OP_andeq] = true,
  [OP_bandeq] = true, [OP_minus] = true, [OP_plus] = true, [OP_mul] = true,
  [OP_div] = true, [OP_lt] = true, [OP_gt] = true, [OP_gte] = true, [OP_lte] = true,
  [OP_concateq] = true, [OP_concat] = true, [OP_pow] = true,
  [OP_poweq] = true, [OP_neq] = true, [OP_blshift] = true, [OP_brshift] = true,
  [OP_bor] = true, [OP_band] = true, [OP_mod] = true
}

local unops = {
  [OP_not] = true, [OP_dec] = true, [OP_inc] = true, [OP_len] = true,
  [OP_at] = true
}

local other_ops = {
  [OP_cond] = true, [OP_san] = true, [OP_special] = true
}

function process_binop(match, token, level, tokens, k)
  if binops[match] then
    local next = tokens[k + 1] or {}
    local prev = tokens[k - 1] or {}

    if token == '%' then
      -- Magic operator
      if next[2] == TK_IDENTIFIER and tokens[k + 2][1] == '[' then
        push_lex_token(level, OP_special, TK_OPERATOR)
        push_lex_token(level, next[1], next[2], next[3])
        push_lex_token(level, SLICE_OPEN, TK_SEPARATOR)

        local i = 3

        while (tokens[k + i] and tokens[k + i][1] != ']') do
          push_lex_token(level, tokens[k + i][1], tokens[k + i][2], tokens[k + i][3])

          i = i + 1
        end

        push_lex_token(level, SLICE_CLOSE, TK_SEPARATOR)

        return
      end
    end

    -- Check that previous is either a raw identifier or a group.
    if prev[2] == TK_IDENTIFIER or prev[2] == TK_LITERAL or prev[1] == ')' then
      local left, right = _read_tk(tokens, k, -1), _read_tk(tokens, k)

      push_lex_token(level, match, TK_OPERATOR)
      _insert_tk(level, left, true)
      _insert_tk(level, right, true)
      push_lex_token(level, OP_separate, TK_SEPARATOR)
    end
  end
end

function process_unop(match, token, level, tokens, k)

end

function process_op(match, token, level, tokens, k)

end
