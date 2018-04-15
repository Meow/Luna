OPERATORS_MATCH = {}

-- Any tokens that are supposed to create new scope
CONTEXT_OPENERS = {
  ['if'] =        true, ['func'] =    true, ['do'] =    true,
  ['for'] =       true, ['while'] =   true, ['class'] = true,
  ['switch'] =    true, ['unless'] =  true, ['fn'] =    true,
  ['namespace'] = true, ['elsif'] =   true, ['else'] =  true,
  ['case'] =      true
}

-- All available token types
TK_NONE       = 0 -- Error
TK_IDENTIFIER = 1 -- Variable names
TK_KEYWORD    = 2 -- Language tokens
TK_SEPARATOR  = 3 -- Punctuation characters
TK_OPERATOR   = 4 -- Operators
TK_LITERAL    = 5 -- Literals
TK_COMMENT    = 6 -- Comments

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

-- Convert most of the previously defined tokens into enums
for k, v in pairs(LUNA_KEYWORDS) do
  reg_op(k)
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
add_keyword('STRAIGHT_START')   -- |
add_keyword('STRAIGHT_END')     -- | wew
add_keyword('GROUP_START')      -- Abstract group
add_keyword('GROUP_END')        -- Abstract group end
add_keyword('CALL')             -- Simply call anything
add_keyword('CALLSELF')         -- Call method b on object a via :
add_keyword('INDEX')            -- Fetch index b from object a via . without calling

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
