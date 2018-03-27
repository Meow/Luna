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

### Default Lua tables are treated differently
Due to the way Luna's OOP works, to interact with Lua tables the way you'd expect, you need to use the ```::``` operator. It acts just like ```.``` in regular Lua, but since Luna uses ```.``` to call class members, we could not keep using it for table indexing.
```
String::sub
Math::random
net::Start
http::Post
```
```lua
string.sub
math.random
net.Start
http.Post
```

Alternatively, in some cases where you do not want your variable called, you can prefix it with ```:```, which means "treat as variable".
```
player.some_var
:player.some_var
```
```lua
player:some_var()
player.some_var
```

Please note that this should only be used where something is being indexed. If you just have a regular variable, it won't work on it.

### Parentheses are optional
Putting parentheses in the function calls is optional in most cases. There are some edge scenarios where this might still be necessary, but generally you don't need to do that anymore
```
my_string = String::gsub 'hello world', 'hello', 'hi'
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
  false
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

### Shorthand way to make tables
You can assign table keys to variables using the ```:``` operator, instead of ```=```.
```
my_table = {
  key: 'value',
  foo: 123,
  bar: 321,
  1, 2, 3,
  a: {
    b: 'c'
  }
}
```
```lua
local my_table = {
  key = 'value',
  foo = 123,
  bar = 321,
  1, 2, 3,
  a = {
    b = 'c'
  }
}
```

### 'then' is optional in logical blocks
```
func foo(arg)
  if arg == 1
    print arg
  end

  if arg == 2
    print arg
  elseif arg == 3
    print 'this number does not exist!'
  else
    print 'error'
  end
end
```
```lua
function foo(arg)
  if arg == 1 then
    print(arg)
  end

  if arg == 2 then
    print(arg)
  elseif arg == 3 then
    print('this number does not exist!')
  else
    print('error')
  end
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
my_string = 'This is an #{String::upper 'amazing'} string!'
```
```lua
local my_string = 'This is an '..(string.upper('amazing'))..' string!'
```

String interpolation is supported by all of the types of strings, including the ```lua [[ ]]``` style.

### Splat arguments
Splat arguments can be imagined as varargs that aren't required to be at the end of the function definition.
```
func foo(*args)
  print :args.bar

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
  print :args.bar
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
fn print 'test' end
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
case 'string', 'strang'
  ...
case 321
case 123
  ...
case false
  ...
else
  ... // default case
end
```
```lua
if (some_condition == 'string' or some_condition == 'strang') then
  ...
elseif (some_condition == 321 or some_condition == 12) then
  ...
elseif (some_condition == false) then
  ...
else
  ... -- default case
end
```

### Classes and object-oriented programming (OOP)
Luna features an implementation of OOP. Since it's compiled into Lua, it won't be nearly as feature-rich as other languages and will be limited to Lua's abilities.

**Luna compiles class code into absolute, utter garbage, and for that reason the examples of the compiled code will only be provided for method calls and definitions.**

Basic class:
```
class MyClass

end
```

Let's make a constructor
```
class MyClass
  func MyClass
    print 'I am a class constructor!'
  end
end
```
```lua
function MyClass:MyClass()
  print('I am a class constructor!')
end
```

How about some member variables
```
class MyClass
  some_var = 123

  func MyClass
    print 'I am a class constructor!'
  end
end
```
```lua
MyClass.some_var = 123

function MyClass:MyClass()
  print('I am a class constructor!')
end
```

Let's make some member function
```
class MyClass
  some_var = 123

  func MyClass
    print 'I am a class constructor!'
  end

  func init

  end
end
```
```lua
MyClass.some_var = 123

function MyClass:MyClass()
  print('I am a class constructor!')
end

function MyClass:init()

end
```

Now let's use our class for something! To do that, we can either use a ```new``` keyword, or just call the ```Class#new``` method.
```
obj1 = new MyClass
obj2 = MyClass.new

obj1.init
```
```lua
obj1 = MyClass:new()
obj2 = MyClass:new()

obj1:init()
```

### Class inheritance
In the previous section we created a ```MyClass``` class, now let's try to extend it! To do that we can either use ```<``` token for classic inheritance, or ```>``` for reverse-inheritance. If that sounds confusing to you, don't worry, we will explain what it is soon enough.

#### Classic inheritance
```
class Foo < MyClass

end
```

Now let's override the ```init``` member of the base class.
```
class Foo < MyClass
  func init

  end
end
```
```lua
function Foo:init()

end
```

The ```Foo#init``` method will not be doing anything right now. Let's say we add some code to it, but we also want to call the base class function. To do that we can simply use the ```super``` keyword, which calls a member of the base class with the same name as the member it was called in. Sounds complicated, but it isn't!
```
class Foo < MyClass
  func init
    print 'Foo#init'

    super
  end
end
```
```lua
function Foo:init()
  print("Foo#init")

  pcall((self.base_class or {}).init or function() end, self)
end
```

It can also be called with arguments, just like any other function.

#### Reverse-inheritance
Now that we've covered the regular old inheritance, let's learn something new. Consider the code from the previous example, except where the ```<``` token is replaced with ```>```:
```
class Foo > MyClass
  func init
    print 'Foo#init'

    super
  end
end
```

With reverse inheritance, this member will do only what the base class member is doing. Reverse inheritance is a kind of inheritance, where the newly created class is a class that would have been if the base class was derived from it. In other words, it initializes new class first, and then copies the base class onto it, rather than the other way around.

This is useful when you want to add onto a class without overwriting it's members at all.

## More features are being developed. Check back later.


# Convention over Configuration
Luna follows the CoC scheme, which means that you are expected to name your variables and function in a certain manner, as well as adhere to a certain coding standard. The convention we based our off is the standard Lua's convention, with small changes to fit modern development needs.

This section will attempt to outline the main points of Luna's convention.

### Variable names
Local variables must be all lowercase with words separated by an underscore (```_```). The names must be meaningful and briefly describe what the variable is used for.

Example:
```
my_variable = 'foo'
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

### Spaces
The following characters **must not** have any trailing / leading spaces: ```[```, ```(```, ```]```, ```)```

You **must** put a trailing space after a comma (```,```)

You **must** surround any logical or assignment operators with spaces. This includes the following: any assignment operator (e.g. ```+=```, ```=```), comparison operators (```==```, ```>=```, etc), logical operators (```and```, ```or```, ```||```, etc) and bitwise operators (```|```, ```&```, etc).

You **must** put a space after an ```if``` condition (this includes ```elseif``` too).

You **should not** put a space before the parentheses in the function definition (```func a(...)```).

In table definitions, the colon (```:```) **must** also be followed by a space.

Example:
```
func foo(a, b, c)
  if a and (b or c)
    return {
      a: a,
      b: b,
      c: c
    }
  end

  b += 100

  return b
end
```

### Parentheses
You should only put parentheses if **absolutely** necessary. This includes function definitions (only if that function accepts arguments), function calls as arguments to another function call and where otherwise required by the syntax.

You **should not** put any parentheses in the logical blocks, unless they are used to separate the conditions (e.g: ```if (a or b) and (c or d)```)

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

### Indentation
Your indentation must be consistent throughout your project. Two spaces should be used for indentation. If inconsistent indentation is detected, the language compiler will throw an error.

All of the code inside functions bodies, ```if``` blocks, loops should be indented. ```switch``` block is not required to be indented if you use indentation within the ```case``` blocks.

Both of the following examples are valid:
```
switch condition
case 0
  ...
case 1
  ...
else
  ...
end
```
```
switch condition
  case 0
    ...
  case 1
    ...
  else
    ...
end
```

### Operators
By convention, you should avoid using the ```||, &&``` operators in your code. Instead use ```or, and```.

Use proper assignment operators whenever possible, for example ```a += b``` instead of ```a = a + b```.

Use ```switch``` when you need to create a if-elseif-else structure.

### Do not repeat yourself (DRY)
Keep your code DRY. Avoid writing the same code over and over again in several places, instead consider making it a function. If you need something for your project, check if there is something that provides what you need in LPM (Luna Package Manager). It's always easier to just write a single line rather than hundreds of lines of code.

If considering adding a library into your project, check if it's on LPM first, rather than copying that library into the project. If the library you want to use is not there, you can always suggest it to be added at luna-lang.net!

### Other libraries may add to the convention
Multiple other libraries (such as database modules) may provide their own additions to this convention (provided that those additions don't go against any of the previous conventions).

Please always check the documentation of the major modules to see if there are any!

