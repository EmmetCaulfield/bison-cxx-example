Modifying the Bison C++ Example to Use a C++ Lexer
==================================================

This document answers the question “What are the absolute minimum
changes necessary to get
[A Complete C++ Example](http://www.gnu.org/software/bison/manual/bison.html#A-Complete-C_002b_002b-Example)
from the [_Bison_ Manual](http://www.gnu.org/software/bison/manual/) to
use a [C++ _Flex_ Lexer](http://flex.sourceforge.net/manual/Cxx.html)?”

It may be surprising that the `bison` “Complete C++ Example” uses the
_C_ `flex` interface, but that's how it is.

The example refers to 5 files:

  * [`calc++.cc`](calc++.cc) — the “main” program
  * [`calc++-driver.hh`](calc++-driver.hh) — the driver class declaration
  * [`calc++-driver.cc`](calc++-driver.cc) — the driver class implementation
  * [`calc++-parser.yy`](calc++-parser.yy) — the `bison` input file
  * [`calc++-scanner.ll`](calc++-scanner.ll) — the `flex` input file

I copy/pasted these from the manual and, initially, added two more files:

  * [`calc++.in`](calc++.in) — the
    “[example of valid input](http://www.gnu.org/software/bison/manual/bison.html#Calc_002b_002b-_002d_002d_002d-C_002b_002b-Calculator)”
    ( which produces “49”) in a file; and
  * [`Makefile`](Makefile) — an ad-hoc _Makefile_

Any changes made to the original files are clearly marked with
“`CHANGE:`” in a comment. If you just want to find those, you can
`grep` the source.

The Problem
-----------

You might think that if you just gave `flex` the `--c++` option (or
specified `%option c++` in the `calc++-scanner.ll`) that everything
would just work, right?

But if you try that, you get 187 lines of:

```
calc++-scanner.cc: In function ‘yy::calcxx_parser::symbol_type yylex(calcxx_driver&)’:
    calc++-scanner.cc:707:9: error: ‘yy_init’ was not declared in this scope
      if ( !(yy_init) )
```

The basic problem here is that now `yy_init` and friends are members
of a class, called `yyFlexLexer` by default, so this definition for
`yylex`'s header in `calc++-driver.hh`:

```c++
// Tell flex the lexer's prototype ...
#define YY_DECL yy::calcxx_parser::symbol_type yylex(calcxx_driver& driver)
// ... and declare it for the parser's sake.
YY_DECL;
```

Well, this definition is wrong now. If you've been reading the
[`flex` manual](http://flex.sourceforge.net/manual/Cxx.html#Cxx),
you'll know it needs to be _something like_:

```c++
// Tell flex the lexer's prototype ...
#define YY_DECL yy::calcxx_parser::symbol_type yyFlexLexer::yylex(calcxx_driver& driver)
// ... and declare it for the parser's sake.
YY_DECL;
```

Right?

If only. Try it and you'll just find that you get another error
instead — “`yyFlexLexer` has not been defined” — so you'll have to
`#include <FlexLexer.h>` somewhere.

The error is not altogether surprising, of course, since all we did
was give the lexer (now a `class`) the header for its own `yylex`
function.

If you `#include <FlexLexer.h>` in the driver's header file, you just
get more errors: the prototype (above) doesn't match anything in
`yyFlexLexer`, and `yylex()` is virtual.

So, you move the `#include` _after_ the `#define YY_DECL`, and let
`FlexLexer.h` provide the declaration by getting rid of the `YY_DECL;`
statement.

Now the _parser_ won't compile: “`yylex` was not declared in this scope”.


An Aside on Flex and Bison
--------------------------

### What They Are ###

If you're interested enough to read this, you doubtless already know
that `flex` is a lexical analyzer generator modeled on the historical
`lex`, that, from a specification, emits code that, when compiled,
_lexes_ or _tokenizes_ its input, which is usually text from a
file. In the best-known use of `lex` and its derivatives, this file
contains statements in some programming language, and the lexer's job
is to recognize the fundamental “atoms” of the language — keywords,
literals, identifiers, punctuation, etc. — as _tokens_ and pass them
on to a _parser_.

Its counterpart, `bison` is a parser generator based on the historical
`yacc` (standing for “yet another compiler compiler” with _bison_
being a play on _yak_) that, from what is essentially a
[BNF grammar](https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_Form),
emits code that, when compiled, interprets a series of tokens from a
lexer, applies grammatical rules to them, and builds an in-memory
representation of the series of tokens according to the semantics of
the grammar. In the case of a compiler, it will build a parse tree
that reflects the language statements in some file.

These two tools are often used together: the `bison`-generated parser
gets its tokens by repeatedly calling a function provided by the
`flex`-generated lexer, almost always called `yylex()`, getting the
next token from the input with each call.

### How They Work ###

Historically, how `lex` and `yacc` and their derivatives, including
`flex` and `bison`, work is basically a rat's maze of preprocessor
directives and naming conventions. You supply little fragments of code
that get slipped into the output (historically _C_ code, but including
_C++_ and _Java_ nowadays) in various places via `#define`s or with
“percent brace” code blocks (i.e. between `%{` and `%}`), or both.

So, depending on what macro you `#define` or where you put your code
blocks, the code _you_ provide goes into a particular place in the
lexer or parser source that `flex` and `bison` emit. For example, in
the first part (before the first `%%` separator) of
`calc++-scanner.ll` there's a stanza like this:

```c++
%{
    // Code run each time a pattern is matched:
    #define YY_USER_ACTION  loc.columns(yyleng);
%}
```

The effect of this is to insert `loc.columns(yyleng);` into the
beginning of every rule. You could have achieved the exact same effect
by prepending the same statement into every rule yourself, or by
putting the `#define` into the first code block where `loc` is
declared. In this case, there's no reason for this to be in a separate
block.

Any code block in the “middle part”, after the first `%%` separator, of
the input file goes straight into `yylex` itself, like this code block:

```c++
%{
    // Code run each time yylex is called:
    loc.step();
}%
```

This mechanism of providing code fragments via `#define`s and “percent
brace” code blocks is how it makes sense to provide `yylex` with its
own function header: the code that that `flex` emits _itself_ doesn't
use those function arguments at all, the bits of code that _you_
provide do.

Back to the Problem
-------------------

So, now you've a better idea how `flex` works and what it expects,
back to the original problem...

In essence, rather than emitting `yylex` as a _C_ function with
external linkage that can be called from anywhere, `flex` has now
emitted a class definition, where `yylex` and friends are _members_
that you need an instance to access.

So that explains why the parser wouldn't compile with “`yylex` was not
declared in this scope”: it isn't any more.

Now that the lexer is an object, in addition to the changes we've
already made, you have to:

  1. Instantiate a lexer object (a `yyFlexLexer`)
  2. Somehow arrange for the _parser_ to call `yylex` via that object.

But how did the parser know how to call `yylex` before?

Well, it knew _to_ call `yylex` because `bison` parsers _always_ call
`yylex`. Previously `yylex` was a function symbol with external
linkage provided by (compiled code emitted by)` flex` that gets
“connected” at link time.

But, as noted earlier, and unsurprising from the similarities between
the input files, `bison` works off a similar mess of preprocessor
macros and code stanzas to `flex`, so to get `bison` to call something
other than `yylex`, you just need to `#define yylex` to something
else.

So, _somewhere_ in `bison`'s input file (`calc++-parser.yy`), you need
something like this:

```c++
#define yylex lexerObject.yylex
```

You might have noticed this in there (same file):

```bison
%param { calcxx_driver& driver }
```

The ultimate effect of this is to tell `bison` what arguments to call
`yylex` with, so there has to be a symmetry between what `flex` was
told and what `bison` was told, and there is: recall from the
(original) driver's header file (`calc++-driver.hh`):

```c++
// Tell flex the lexer's prototype ...
#define YY_DECL yy::calcxx_parser::symbol_type yylex(calcxx_driver& driver)
// ... and declare it for the parser's sake.
YY_DECL;
```

See how the arguments match?

For `bison` to be able to call `yylex` with an object, though, it
must get it _from_ somewhere, so the effect of the `%param`
declaration, in more detail, is to get `bison` to:

   1. add a member declaration, `calcxx_driver& driver;`, to the
      parser class it emits;
   2. add a one-argument constructor that initializes `driver` with
      the argument; and
   3. call `yylex(driver)` when it wants the next token.

So, that explains _this_ line:

```c++
    yy::calcxx_parser parser (*this);
    
```

... which you'll find in the driver's `parse()` function in
`calc++-driver.cc`. In short, the driver hands the parser's
constructor a reference to itself, and when the driver calls `yylex`,
it passes it on to the lexer.

But what does the _lexer_ want with a reference to the _driver_?

In short: nothing, really. The only thing the lexer currently does
with the driver is call `driver.error()` to do error-reporting.


Solution Path of Least Resistance
---------------------------------

So, the path of least resistance would appear to be to add the lexer
object to the _driver_, which is already passed to the parser's
constructor, and then get the parser to invoke `yylex` via _that_.

Assuming we add `lexer` as a member of `calcxx_driver` and initialize
it appropriately, we still have a choice to make: the lexer gets a
reference to the driver via the argument to `yylex`, so we can either
do something like:

```c++
#define yylex driver.lexer.yylex
```

... _or_ we could add a proxy forwarding function to the driver (let's
call it `yylex` too), and do:

```c++
#define yylex driver.yylex
```

Either way, `yylex` is called via the driver in some way.

Now, the driver has a zero-argument constructor and gets the name of
the file to work on when `main()` calls its `parse()` function.

This means that the `lexer` member cannot be a reference, since it
can't be instantiated in the constructor's initializer list. We have
two remaining choices:

  1. we can make `lexer` a “vanilla” member, allow it to be
     constructed via the zero-argument constructor with default input
     and output streams, and then pass the input stream to use via
     `switch_streams()` or `yyrestart()`, _or_

  2. we can make the `lexer` member a pointer, and pass the input
     stream to the constructor when we create the lexer with `new`.

Of the two, I prefer the first one, since we don't then have to make
any changes to the driver's destructor to `delete` anything created
with `new`.

### More yyFlexLexer Problems ###

Unfortunately, even after all this, you can't simply `#include
<FlexLexer.h>` and have everything go according to plan.

The reason for this is that, while you can use `YY_DECL` successfully
to set the function header for `yylex` in the _definition_ of `yylex`
that `flex` emits into `calc++-scanner.cc`, there is no analagous way
of getting the _declaration_ to match, because `FlexLexer.h` bizarrely
lacks support for `YY_DECL`.

The `flex` manual clearly says that
“[The ‘--header-file’ option is not compatible with the ‘--c++’ option, since the C++ scanner provides its own header in yyFlexLexer.h.](http://flex.sourceforge.net/manual/Options-for-Specifying-Filenames.html#Options-for-Specifying-Filenames)”

This is wrong in two ways. First, the “provided” header file is
`FlexLexer.h`, not `yyFlexLexer.h`; and, second, `flex` will happily
emit a header file in _C++_ mode: it just doesn't do us any good!

So, to cut a long story short: there is currently no support for
getting the _declaration_ of `yyFlexLexer` to use a prototype for
`yylex` other than `int yylex()`. None. Period.

The choices are:

  1. Modify `FlexLexer.h` (perhaps automatically with `sed`/`awk`),
     and include the modified file instead.

  2. Modify the lexer so it doesn't use the driver for error
     reporting, and returns an `int`, so it can use the default
     version of `yylex()`.

  3. Write a subclass of `yyFlexLexer` that provides a version of
     `yylex` with the required prototype.

The first option is not the kind of thing I'd shy away from if there
were no other options. All you really have to do is insert the right
function prototype in the right place. That said, it is really too
“hacky” to be considered a good solution.

The second option is excessively invasive because `yylex` is
configured to return a `yy::calcxx_parser::symbol_type` _object_, so
exercising this option would require changes everywhere this return
value is used.

It turns out that `flex` has two options that affect the name of the
lexer class, neither of which we need in this case, but which warrant
mention if only to avoid confusion:

  * `%option prefix="Foo"` — output class is `FooFlexLexer`
  * `%option yyclass="Bar"` — output class is `Bar`

So, it seems like the third option, subclassing `yyFlexLexer`, is the
one to go for. To distinguish it clearly from the manual examples, we
call this class [`CalcFlexLexer`](CalcFlexLexer.hh). To use it, the
header for `yylex` used by the _definition_ becomes:

```c++
#define YY_DECL yy::calcxx_parser::symbol_type CalcFlexLexer::yylex(calcxx_driver& driver)

```

### Moving Some Code ###

Did you notice that some driver functions were defined at the bottom
of the `flex` input file? These ones:

```c++
void calcxx_driver::scan_begin()
{
    yy_flex_debug = trace_scanning;
    if( file.empty () || file == "-" ) {
        yyin = stdin;
    } else if (!(yyin = fopen (file.c_str (), "r"))) {
        error ("cannot open " + file + ": " + strerror(errno));
        exit (EXIT_FAILURE);
    }
}

void calcxx_driver::scan_end ()
{
    fclose (yyin);
}
``` 

Those (formerly global) variables, `yyin` and `yy_flex_debug`, are in
the `CalcFlexLexer`/`yyFlexLexer`/`FlexLexer` object now and, frankly,
it was always a bit smelly to have part of the implementation of the
driver class shoved into the end of the `flex` input file.

We must arrange to have `scan_begin()` and `scan_end()` do the
equivalent thing with streams, working via the lexer object's
interface, so we do three things:

  1. Add a `std::ifstream` to the driver class;
  2. Move the `scan_begin()` and `scan_end()` functions out of the end
     of `calc++-scanner.ll` into `calc++-driver.cc`; and
  3. Modify them so they use streams instead of `FILE` pointers.

### A Bug in Flex? ###

When we make these changes, we find that the compiler chokes on
differing definitions of `isatty()`: the one from `unistd.h`, and the
one that `flex` (for some reason) emits into `calc++-scanner.cc`,
which (in the _C++_ case) differ in that the one in `unistd.h` is
declared to throw an exception.

By a stroke of pure luck, there is a way of excluding `unistd.h`:

```c++
#define YY_NO_UNISTD_H
```

So we add that to the `flex` input file (`calc++-scanner.ll`), and
this error goes away.

### Almost There ###

Having made all these changes, the code compiles.

But it won't _link_:

```
gcc   calc++.o calc++-driver.o calc++-parser.o calc++-scanner.o  -lstdc++ -o calc++
calc++-driver.o:(.rodata._ZTV13CalcFlexLexer[_ZTV13CalcFlexLexer]+0x40): undefined reference to `yyFlexLexer::yylex()'
calc++-scanner.o:(.rodata._ZTV11yyFlexLexer[_ZTV11yyFlexLexer]+0x40): undefined reference to `yyFlexLexer::yylex()'
collect2: error: ld returned 1 exit status
make: *** [calc++] Error 1
```

It seems that, somehow, somewhere, the driver and the lexer are
referencing the zero-argument version of `yylex`.

By using `YY_DECL` the way we did, we replaced the default function
header `int yyFlexLexer::yylex()` with `yy::calcxx_parser::symbol_type
CalcFlexLexer::yylex(calcxx_driver& driver);` in the `.cc` file
emitted by `flex`, but the prototype `int yylex()` still appears in
the declaration of `yyFlexLexer` in `FlexLexer.h`, which we have no
control over.

In short, this means that there is no object code implementing `int
yyFlexLexer::yylex()`, which the linker won't accept. The fact that
this version of `yylex` is never called is beside the point: _if_ it's
referenced by any compiled code, and it _is_ because `FlexLexer.h` is
ultimately included by a few files, the linker expects to be able to
resolve the symbol.

To fix this, we put a dummy implementation of `int
yyFlexLexer::yylex()` into the third “extra code” section of the lexer
input file, `calc++-scanner.ll`, and try to compile again.

Success!
--------

It compiles. It works. And that, as they say, is that.

### Summary ###

_One_ file, [`CalcFlexLexer.hh`](CalcFlexLexer.hh), was _added_.

It contains a simple class that extends `yyFlexLexer` to overload
`yylex` with a version that has the required prototype.

_Nine_ changes, of which 8 are essential, were made to 3 files.

_Four_ changes were made to the driver header file,
[`calc++-driver.hh`](calc++-driver.hh):

  * Added `#include <fstream>` to the top
  * Replaced `#define YY_DECL ...` with `#include "CalcFlexLexer.hh"`
  * Added `std::ifstream instream` as a member of the class (`calcxx_driver`)
  * Added `CalcFlexLexer lexer` as a member of the class (`calcxx_driver`)

_Four_ changes, one cosmetic, were made to the `flex` input file,
[`calc++-scanner.ll`](calc++-scanner.ll):

  * Moved `#define YY_USER_ACTION ...` from its own code block into
    first one (a purely cosmetic change)
  * Added `#define YY_NO_UNISTD_H` to suppress a compiler error.
  * Removed driver function definitions from the third, “extra code”,
    part of the file.
  * Added a dummy implementation of `int yyFlexLexer::yylex()` to
    prevent linker choking.

_One_ change was made to the driver implementation file,
[`calc++-driver.cc`](calc++-driver.cc):

  * Added (modified versions of) the member functions removed from the
    bottom of `calc++-scanner.ll`

Could that _really_ be the path of least resistance?

I believe so.

The only remaining change that I would make is to move the `static`
variable, `loc`, declared in the lexer input file, into one of the
objects. Not making this change prevents this implementation from
being fully re-entrant, but the goal was to make the _minimum
necessary changes_ to get the `bison` _C++_ example code to work with
a _C++_ `flex` lexer, not to fix all of the example code's
shortcomings.
