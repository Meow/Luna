# Luna-Parser
Luna language parser. Compiles Luna sources to Lua.

Luna is an alternative syntax for the Lua language. This version of the parser is specifically designed for Garry's Mod.

Luna features tons of syntax changes over the original Lua to make it easier for programmers to write code. The goal of the project is to lower the amount of typing that needs to be done by the coder, as well as provide convenient and easy-to-read syntax.

Luna is heavily inspired by Ruby, but also takes certain features from JS, C# and C++.

# Installation
Luna relies on something calling the ```Lua_Preprocess``` hook via either Garry's Mod's hooks system or Luna's implementation of it. So just drop the project somewhere and include the init.lua file. Note that it overwrites and aliases certain build-in GMod functions and that this parser doesn't feature anything that calls the preprocessor hook.

# Syntax documentation
Luna supports writing Lua code directly and it should (in most cases) be nicely ignored and untouched by the parser. Some code might not be compatible, the only real way to know for sure if your Lua code will be ignored by the Luna parser is to just drop it there and see if it works.

Here is a (non-comprehensive) list of what is new, in no particular order:
### The language is indentation-sensitive
Before I say anything else, I need to point out that the language relies on proper indentation of the document. You don't need to use some specific indentation, the only requirement is for you to be consistent. A lot of Luna's features may break if your indentation is inconsistent and the compiler will warn you against that.

Your indentation must be at least one space or one tab. Two spaces are used in the examples, as this is the convention that Luna follows.

### New assignment operators
```
+= -= *= /= %= or= and= &&= ||= &= |= ^= ..=
```

Also the ```++``` operator. ```--``` was not implemented due to overlapping Lua's comments.

### Bitwise operators
```
| & << >>
```

### Operator aliases
The following tokens were aliased:
```
func       -> function
elif/elsif -> elseif
yes/no     -> true/false
is         -> ==
is not     -> !=
```

### Variables are local by default
All of the variables are local by default, which means that you don't need to specify the ```local``` keyword anymore. If the variable is found in the global table, it will be treated as global, unless explicitly marked local.

Functions are always treated as globals unless explicitly marked local.

The ```global``` (or ```glob```) keyword allows you to explicitly declare the variable as global.
```
global var = true
test = 123
foo = 'hello!'
foo = 'world'
SOME_GLOBAL_VAR = 123 // Assuming this variable exists in _G table
```
```lua
var = true
local test = 123
local foo = 'hello!'
foo = 'world'
SOME_GLOBAL_VAR = 123 // Assuming this variable exists in _G table
```

### Parentheses are optional
Putting parentheses in the function calls is optional in most cases. There are some edge scenarios where this might still be necessary, but generally you don't need to do that anymore
```
var my_string = string.gsub 'hello world', 'hello', 'hi'
```
Will get pre-processed into
```lua
local my_string = string.gsub('hello world', 'hello', 'hi')
```

They are also optional in the function definitions, if the function does not take any arguments
```
func my_func
  print 'hello world'
end
```
```lua
function my_func()
  print('hello world')
end
```

### Function definitions
Function definitions now support default arguments and two new characters in them.
```
func foo(arg = 100)
  print arg
end
```
```lua
function foo(arg)
  if (arg == nil) then arg = 100 end
  print(arg)
end
```
The characters ```!``` and ```?``` are now also valid characters in the function names.
```
func this_returns_bool?
  return false
end

func dangerous_func!
  do_something_dangerous
end
```
```lua
function this_returns_bool__bool()
  return false
end

function dangerous_func__excl()
  return do_something_dangerous()
end
```

### Implicit returns
The last statement of the function will be automatically returned.
```
func foo
  'this will be returned'
end
```
```lua
function foo()
  return 'this will be returned'
end
```

### Methods can be called on literals
You can call certain methods directly on numbers and strings, as well as tables.
```
100.random
'hello world'.upper
{1, 2, 3}.each k, v do ... end
```
```lua
math.random(100)
string.upper('hello world')
for k, v in pairs({1, 2, 3}) do ... end
```

```string.``` library will be used on strings, ```math.``` on numbers. Methods that can be used on anything will be used on tables.

### String interpolation
Luna supports string interpolation.
```
var my_string = 'This is an #{string.upper 'amazing'} string!'
```
```lua
local my_string = 'This is an '..(string.upper('amazing'))..' string!'
```

String interpolation is supported by all of the types of strings, including the ```lua [[ ]]``` style.

### Splat arguments
Splat arguments can be imagined as varargs that aren't required to be at the end of the function definition.
```
func foo(*args)
  print args.bar

  args.each k, v do
    print k, v
  end
end

foo 'a', bar: 'hello', 'b', 'c', 'd' // prints: hello a b c d
foo bar: 'bye' // prints: bye
```
```lua
function foo(args)
  print(args.bar)

  for k, v in pairs(args) do
    print(k, v)
  end
end

foo({'a', ['bar'] = 'hello', 'b', 'c', 'd'})
foo({['bar'] = 'bye'})
```

This is also valid with splat arguments:
```
func foo(a, *args, b)
  print a
  print args.bar
  print b
end

foo bar: 'this is between a and b', 'a', 'b' // prints: a this is between a and b b
foo bar: "you don't necessarily have to provide all of the arguments for it to work"
```
```lua
function foo(a, b, args)
  print(a)
  print(args.bar)
  print(b)
end

foo('a', 'b', {['bar'] = 'this is between a and b'})
foo(nil, nil, {['bar'] = "you don't necessarily have to provide all of the arguments for it to work"})
```

**Splat arguments are limited to one splat argument per function.**

### Yield blocks
Yield blocks are functions / code blocks that can be executed by calling the ```yield``` special function anywhere inside of your function's body. This is, however, different from passing a function as an argument, as this method reads the first do-end block after the function call and passes it as the callback. Plus it's plain shorter to write a yield block than mess with arguments.
```
func foo
  yield
end

func bar
  yield 'hello'
end

foo do
  print 'test'
end

bar do(message)
  print message
end
```
```lua
function foo(_yield)
  return _yield()
end

function bar(_yield)
  return _yield('hello')
end

local function __yield_block()
  return print('test')
end
foo(__yield_block)

local function __yield_block(message)
  return print(message)
end
bar(__yield_block)
```
Yield blocks can be mixed with splat arguments, the compiler is aware of both of them and tries to play nicely.

### Namespaces
Namespaces is a common concept for a lot of programming languages. In Luna they are a lot like C#'s namespaces.
```
namespace Test
  some_var = 'test string'

  func foo
    print 'yay'
  end
end

Test.foo
```
They are not using tables and simply pre-process into something like this:
```lua
Test__some_var = 'test string'

function Test__foo()
  print('yay')
end

Test__foo()
```
Namespaces can also be nested inside of each other
```
namespace Test
  namespace Foo
    func bar
      print 'test'
    end
  end
end

Test.Foo.bar
```
```lua
function Test__Foo__bar()
  print('test')
end

Test__Foo__bar()
```

### Single-line logical statements
Logical statements that only take a single line can be written like this:
```
code if/unless condition
```
```
return false if my_var == 'error'
return false unless my_var != 'error' // Equivalent of above
```
```lua
if (my_var == 'error') then return false end
if !(my_var != 'error') then return false end
```

### Anonymous functions
There is a shorthand way to define anonymous functions
```
fn() print 'test' end
fn(a, b, c) print a, b, c end
```
```lua
function() print('test') end
function(a, b, c) print(a, b, c) end
```

### Switches
Just like a lot of other languages, Luna features the ```switch``` conditions.
```
switch some_condition
case 'string'
  ...
case 123
  ...
case false
  ...
else
  ... // default case
end
```
```lua
if (some_condition == 'string') then
  ...
elseif (some_condition == 123) then
  ...
elseif (some_condition == false) then
  ...
else
  ... -- default case
end
```

## More features are being developed. Check back later.

# Convention over Configuration
Luna follows the CoC scheme, which means that you are expected to name your variables and function in a certain manner, as well as adhere to a certain coding standard. The convention we based our off is the standard Lua's convention, with small changes to fit modern development needs.

This section will attempt to outline the main points of Luna's convention.

### Variable names
Local variables must be all lowercase with words separated by an underscore (```_```). The names must be meaningful and briefly describe what the variable is used for.

Example:
```
var my_variable = 'foo'
```

Global variables have additional rules depending on their purpose.

If a global variable is a constant or enumeration, it should be all uppercase
```
MY_CONSTANT = 'something'

ENUM_ONE    = 1
ENUM_TWO    = 2
ENUM_THREE  = 3
```

Otherwise globals follow the same rules as locals.

### Function names
Functions that are not a part of any table must be named just like local variables.
```
func my_function
  print 'test'
end
```

If a function is a part of a table, it's name must be a single lowercase word that describes it's purpose as good as possible. It must be preceeded by a dot.
```
func lib.new(...)
  ...
end

func my_lib.parse(...)
  ...
end
```

If a function name **absolutely** requires to have two words in it, follow the local variable naming convention.

If you have a table-inside-table structure, the functions should be preceeded by a colon (```:```)
```
func lib.feature:function(...)
  ...
end
```

### Namespace and class names
Names of namespaces and classes must be UpperCamelCase.
```
namespace MyNamespace
  ...
end

class MyClass

end
```

### Method names
Methods of namespaces or classes should be named just like locals.
```
class MyClass
  func some_method
    ...
  end
end
```

### Newlines
You should put a newline before an ```if``` logical block, any loop (```for```, ```while```), ```return``` statement, ```continue``` or ```break```, unless they are directly preceeded by the function definition.

```
func foo
  if condition
    ...
  end

  if other_cond
    ...
  end

  tab.each k, v do
    ...

    break
  end
end
```
