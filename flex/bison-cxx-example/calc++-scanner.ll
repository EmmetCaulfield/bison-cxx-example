/* -*- c++ -*- */
%{
#include <cerrno>
#include <climits>
#include <cstdlib>
#include <string>

#include "calc++-driver.hh"
#include "calc++-parser.hh"

// Work around an incompatibility in flex (at least versions
// 2.5.31 through 2.5.33): it generates code that does
// not conform to C89.  See Debian bug 333231
// <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=333231>.
# undef yywrap
# define yywrap() 1

// CHANGE: "Code run each time a pattern is matched" moved from its
// own block below (this change was not strictly necessary).
#define YY_USER_ACTION  loc.columns (yyleng);

// CHANGE: We must exclude unistd.h or the compiler will choke on the
// `isatty()` declaration emitted by `flex` having a different
// exception specifier from the one in `unistd.h`:
#define YY_NO_UNISTD_H

%}

/* Options: */
%option noyywrap nounput batch debug noinput

/* Regex abbreviations: */
id    [a-zA-Z][a-zA-Z_0-9]*
int   [0-9]+
blank [ \t]

%%

%{
    // Code run each time yylex is called.
    loc.step ();
%}

{blank}+   loc.step ();
[\n]+      loc.lines (yyleng); loc.step ();

"-"      return yy::calcxx_parser::make_MINUS(loc);
"+"      return yy::calcxx_parser::make_PLUS(loc);
"*"      return yy::calcxx_parser::make_STAR(loc);
"/"      return yy::calcxx_parser::make_SLASH(loc);
"("      return yy::calcxx_parser::make_LPAREN(loc);
")"      return yy::calcxx_parser::make_RPAREN(loc);
":="     return yy::calcxx_parser::make_ASSIGN(loc);

{int}      {
    errno = 0;
    long n = strtol (yytext, NULL, 10);
    if (! (INT_MIN <= n && n <= INT_MAX && errno != ERANGE))
        driver.error (loc, "integer is out of range");
    return yy::calcxx_parser::make_NUMBER(n, loc);
}

{id}       return yy::calcxx_parser::make_IDENTIFIER(yytext, loc);

.          driver.error (loc, "invalid character");

<<EOF>>    return yy::calcxx_parser::make_END(loc);
%%

// CHANGE: The "parts of the driver that need lexer data" have been
// moved to calc++-driver.cc (where they really belong) and access the
// new lexer object via its public interface.

// CHANGE: The linker will choke if there's no implementation of the
// default `yylex` even if it's never called.
int yyFlexLexer::yylex() {
    std::cerr << "'int yyFlexLexer::yylex()' should never be called." << std::endl;
    exit(1);
}
