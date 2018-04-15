COMPILERS = COMPILERS or {}
CURRENT_COMPILATION = nil
CURRENT_INDENTATION = nil

local token_translation = {
  ['!'] = 'not', ['!='] = '~=',
  ['&&'] = 'and', ['||'] = 'or'
}

function emit_code(code)
  CURRENT_COMPILATION = CURRENT_COMPILATION..code
end

function emit_indented(code)
  emit_code(CURRENT_INDENTATION..code)
end

function emit_line(code)
  emit_indented(code..'\n')
end

function group_to_string(tree)
  local output = ''

  for k, v in ipairs(tree) do
    output = output..convert_token(v)..' '
  end

  return output:trim()
end

function convert_token(tk)
  if tk[2] == TK_IDENTIFIER then
    return tk[1]:gsub('?', '_b'):gsub('!', '_d')
  end

  return token_translation[tk[1]] or tk[1]
end

function compile_current_scope(tree, ind, prev_ind)
  -- .keep
end

function process_tree(tree, ind)
  -- .keep
end

function compile_to_lua(tree)
  CURRENT_COMPILATION = ''
  CURRENT_INDENTATION = ''

  local is_root_node = false

  local function _compile_scope(tree, ind, prev_ind)
    ind = ind or ''
    prev_ind = prev_ind or ind
    CURRENT_INDENTATION = ind

    -- Root node
    if CURRENT_COMPILATION == '' then
      for k, v in ipairs(tree) do
        if istable(v) and k != 'previous_level' then
          if v.id or v.tk or v.previous_level then
            compile_current_scope(v)
          end
        end
      end
    end

    if tree.tk == 'func' and tree.name then
      emit_line('function '..group_to_string(tree.name)..'()')

      process_tree(tree, ind)

      emit_line('end')
    elseif isfunction(COMPILERS[tree.tk]) then
      COMPILERS[tree.tk](tree, ind)

      if tree.put_end then
        emit_line('end')
      end
    end

    CURRENT_INDENTATION = prev_ind
  end

  compile_current_scope = _compile_scope
  process_tree = function(tree, ind)
    for k, v in ipairs(tree) do
      if istable(v) and k != 'previous_level' then
        compile_current_scope(v, ind..'  ', ind)
      end
    end
  end

  _compile_scope(tree)

  return CURRENT_COMPILATION
end
