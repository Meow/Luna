OPERATORS_MATCH = {}

-- Any tokens that are supposed to create new scope
CONTEXT_OPENERS = {
  ['if'] =        true, ['func'] =    true, ['do'] =    true,
  ['for'] =       true, ['while'] =   true, ['class'] = true,
  ['switch'] =    true, ['unless'] =  true, ['fn'] =    true,
  ['namespace'] = true, ['elsif'] =   true, ['else'] =  true,
  ['case'] =      true
}

-- Literals (registered tokens that aren't operators)
LUNA_LITERALS = {
  ['false'] = true, ['true'] =  true,
  ['yes'] =   true, ['no'] =    true,
  ['nil'] =   true
}

-- Luna operator keywords
LUNA_KEYWORDS = {
  ['if'] =        true, ['elsif'] =     true, ['else'] =  true,
  ['func'] =      true, ['do'] =        true, ['end'] =   true,
  ['return'] =    true, ['for'] =       true, ['while'] = true,
  ['class'] =     true, ['namespace'] = true, ['break'] = true,
  ['continue'] =  true, ['yield'] =     true, ['new'] =   true,
  ['switch'] =    true, ['case'] =      true, ['super'] = true,
  ['unless'] =    true, ['is'] =        true, ['not'] =   true,
  ['and'] =       true, ['or'] =        true, ['fn'] =    true
}

-- Operator enumerations
local operators = {
  'eq', 'gt', 'lt', 'gte', 'lte', 'assign', -- == > < >= <= =
  'plus', 'minus', 'mul', 'div', 'pluseq',  -- + - * / +=
  'minuseq', 'muleq', 'diveq', 'mod',       -- -= *= /= %
  'modeq', 'bor', 'band', 'blshift',        -- %= | & <<
  'brshift', 'inc', 'dec', 'len', 'pow',    -- >> ++ -- # ^
  'poweq', 'concat', 'concateq', 'at',      -- ^= .. ..= @
  'bandeq', 'boreq', 'cond', 'neq',         -- &= |= ?: !=
  'oreq', 'andeq', 'san', 'special',        -- or= and= @ %
  'inherit', 'rinherit',                    -- < >
  'separate', 'eof'                         -- reserved for token separators and end-of-file
}

local last_op = 0
local ops = {}

local function add_keyword(op)
  _G[op] = last_op
  ops[op] = last_op
  OPERATORS_MATCH[last_op] = op

  last_op = last_op + 1
end

local function reg_op(op)
  add_keyword('OP_' + op)
end

local function reg_tk(op)
  add_keyword('TK_' + op)
end

-- Convert most of the previously defined tokens into enums
for k, v in pairs(LUNA_KEYWORDS) do
  reg_tk(k)
end

for k, v in ipairs(operators) do
  reg_op(v)
end

-- Special tokens for the parser
add_keyword('CURLY_OPEN')       -- {
add_keyword('CURLY_CLOSE')      -- }
add_keyword('SLICE_OPEN')       -- [
add_keyword('SLICE_CLOSE')      -- ]
add_keyword('ROUND_OPEN')       -- (
add_keyword('ROUND_CLOSE')      -- )
add_keyword('STRAIGHT')         -- |
add_keyword('GROUP_START')      -- Abstract
add_keyword('GROUP_END')        -- Abstract
add_keyword('CALL')             -- Simply call anything
add_keyword('CALLSELF')         -- Call method b on object a via :
add_keyword('INDEX')            -- Fetch index b from object a via . without calling
add_keyword('LIT_BOOL')         -- true/false
add_keyword('LIT_STRING')       -- 'string'
add_keyword('LIT_STRINGD')      -- "string"
add_keyword('LIT_NUMBER')       -- 123
add_keyword('LIT_NIL')          -- nil
add_keyword('IDENTIFIER')       -- anything
add_keyword('COMMENT')          -- // hello world
add_keyword('SEP_COMMA')        -- ,
add_keyword('SEP_DOT')          -- .
add_keyword('SEP_COLON')        -- :
add_keyword('SEP_SEMICOLON')    -- ;
add_keyword('SEP_NEWLINE')      -- \n
add_keyword('SEP_DOUBLE')       -- ::



-- Match a literal string with an enumerated operator
TOKEN_MATCH = {
  ['+'] = OP_plus,      ['-'] = OP_minus,   ['=='] = OP_eq,     ['+='] = OP_pluseq,
  ['-='] = OP_minuseq,  ['*='] = OP_muleq,  ['/='] = OP_diveq,  ['%='] = OP_modeq,
  ['|='] = OP_boreq,    ['&='] = OP_bandeq, ['<='] = OP_lte,    ['>='] = OP_gte,
  ['>'] = OP_gt,        ['<'] = OP_lt,      ['='] = OP_assign,  ['++'] = OP_inc,
  ['--'] = OP_dec,      ['%'] = OP_mod,     ['..'] = OP_concat, ['..='] = OP_concateq,
  ['#'] = OP_len,       ['^'] = OP_pow,     ['^='] = OP_poweq,  ['<<'] = OP_blshift,
  ['>>'] = OP_brshift,  ['@'] = OP_at,      ['!='] = OP_neq,    ['*'] = OP_mul,
  ['/'] = OP_div,       ['!'] = OP_not,     ['or='] = OP_oreq,  ['||='] = OP_oreq,
  ['and='] = OP_andeq,  ['&&='] = OP_andeq
}

KEYWORD_MATCH = {
  ['if'] = TK_if,             ['elsif'] = TK_elsif,         ['else'] = TK_else,
  ['func'] = TK_func,         ['do'] = TK_do,               ['end'] = TK_end,
  ['return'] = TK_return,     ['for'] = TK_for,             ['while'] = TK_while,
  ['class'] = TK_class,       ['namespace'] = TK_namespace, ['break'] = TK_break,
  ['continue'] = TK_continue, ['yield'] = TK_yield,         ['new'] = TK_new,
  ['switch'] = TK_switch,     ['case'] = TK_case,           ['super'] = TK_super,
  ['unless'] = TK_unless,     ['is'] = TK_is,               ['not'] = TK_not,
  ['and'] = TK_and,           ['or'] = TK_or,               ['fn'] = TK_fn
}

SEPARATOR_MATCH = {
  ['('] = ROUND_OPEN, [')'] = ROUND_CLOSE,
  ['['] = SLICE_OPEN, [']'] = SLICE_CLOSE,
  ['{'] = CURLY_OEPN, ['}'] = CURLY_CLOSE,
  ['|'] = STRAIGHT,   [','] = SEP_COMMA,
  ['.'] = SEP_DOT,    [';'] = SEP_SEMICOLON,
  [':'] = SEP_COLON,  ['\n'] = SEP_NEWLINE
}

LITERAL_MATCH = {
  ['nil'] = LIT_NIL,    ['true'] = LIT_BOOL,
  ['false'] = LIT_BOOL, ['yes'] = LIT_BOOL,
  ['no'] = LIT_BOOL
}
