luna = luna or {}
local errors = {}
local interrupt = false

include('util/lint.lua')
--include('util/minifier.lua')
--include('util/packager.lua')
--include('util/helpers.lua')

ERROR_MINOR = 0
ERROR_WARNING = 1
ERROR_CRITICAL = 2

function throw_error(error, severity, where)
  table.insert(errors, {error, severity, where})

  if severity == ERROR_CRITICAL then
    interrupt = true
  end
end

local map = {
  [0] = 'TK_NONE',
  'TK_IDENTIFIER',
  'TK_KEYWORD',
  'TK_SEPARATOR',
  'TK_OPERATOR',
  'TK_LITERAL',
  'TK_COMMENT'
}

include('src/definitions.lua')
include('src/tokenizer.lua')
include('src/evaluator.lua')
include('src/evaluator/process.lua')
include('src/evaluator/conditions.lua')
include('src/evaluator/operators.lua')
include('src/compiler.lua')
include('src/compiler/logic.lua')

hook.Add('Lua_Preprocess', 'Luna', function(code, path, context)
	if (!path:find('.lun')) then
		return code
	end

	-- Do not lint in prod
	if (DEBUG) then
		linter.check(code)
	end

  -- Convert CRLF into LF
  code = code:gsub('\r\n', '\n')

  -- Add a trailing newline
  if (code:ends('\n')) then
    code = code..'\n'
  end

  local tokens = tokenize(code)

  if (interrupt and istable(tokens) and #tokens > 0) then
    return code
  end

  --for k, v in ipairs(tokens) do
  --  print(v[1]:gsub('\n', '\\n')..'\t'..map[v[2]])
  --end

  local lex_tree = build_lex_tree(tokens)

  --PrintTable(lex_tree)

  local result = compile_to_lua(lex_tree)

  if result then
    print("Compiled Lua:")
    print(result)
    return result
  end

	return code
end)
