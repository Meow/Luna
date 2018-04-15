local shared = {}

COMPILERS['if'] = function(tree, ind)
  if tree.cond then
    emit_line('if '..group_to_string(tree.cond)..' then')

    process_tree(tree, ind)

    if !tree.no_end then
      emit_line('end')
    end
  else
    throw_error('Missing logical condition', ERROR_CRITICAL)
    return
  end
end

COMPILERS['elsif'] = function(tree, ind)
  if tree.cond then
    emit_line('elseif '..group_to_string(tree.cond)..' then')

    process_tree(tree, ind)

    if !tree.no_end then
      emit_line('end')
    end
  else
    throw_error('Missing logical condition', ERROR_CRITICAL)
    return
  end
end

COMPILERS['else'] = function(tree, ind)
  emit_line('else')

  process_tree(tree, ind)
end

COMPILERS['switch'] = function(tree, ind)
  shared['switch'] = group_to_string(tree.cond)
  shared['case'] = nil
end

COMPILERS['case'] = function(tree, ind)
  local comp = shared['switch']

  if !shared['case'] then
    emit_indented('if ')
    shared['case'] = true
  else
    emit_indented('elseif ')
  end

  for k, v in ipairs(tree.cond) do
    if v[2] == TK_IDENTIFIER or v[2] == TK_LITERAL then
      emit_code('(' + comp + ' == ' + v[1] + ')')
    elseif v[1] == ',' then
      emit_code(' or ')
    end
  end

  emit_code(' then\n')
end
