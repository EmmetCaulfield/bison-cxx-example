#pragma once

#ifndef YY_DECL
#define YY_DECL                                                         \
    yy::calcxx_parser::symbol_type CalcFlexLexer::yylex(calcxx_driver& driver)
#endif

// We need this for yyFlexLexer. If we don't #undef yyFlexLexer, the
// preprocessor chokes on the line `#define yyFlexLexer yyFlexLexer`
// in `FlexLexer.h`:
#undef yyFlexLexer
#include <FlexLexer.h>

// We need this for the yy::calcxx_parser::symbol_type:
#include "calc++-parser.hh"

// We need this for the yy::location type:
#include "location.hh"

class CalcFlexLexer : public yyFlexLexer {
public:
    // Use the superclass's constructor:
    using yyFlexLexer::yyFlexLexer;

    // Provide the interface to `yylex`; `flex` will emit the
    // definition into `calc++-scanner.cc`:
    yy::calcxx_parser::symbol_type yylex(calcxx_driver& driver);

    // This seems like a reasonable place to put the location object
    // rather than it being static (in the sense of having internal
    // linkage at translation unit scope, not in the sense of being a
    // class variable):
    yy::location loc;
};
