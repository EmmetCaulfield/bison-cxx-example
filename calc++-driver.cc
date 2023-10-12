#include "calc++-driver.hh"
#include "calc++-parser.hh"

calcxx_driver::calcxx_driver ()
    : trace_scanning (false), trace_parsing (false)
{
    variables["one"] = 1;
    variables["two"] = 2;
}

calcxx_driver::~calcxx_driver ()
{
}

int calcxx_driver::parse (const std::string &f)
{
    file = f;
    scan_begin ();
    yy::calcxx_parser parser (*this);
    parser.set_debug_level (trace_parsing);
    int res = parser.parse ();
    scan_end ();
    return res;
}

void calcxx_driver::error (const yy::location& l, const std::string& m)
{
    std::cerr << l << ": " << m << std::endl;
}

void calcxx_driver::error (const std::string& m)
{
    std::cerr << m << std::endl;
}

// CHANGE: functions moved from the bottom of `calc++-scanner.ll`

void calcxx_driver::scan_begin()
{
    lexer.set_debug( trace_scanning );

    // Try to open the file:
    instream.open(file);

    if( instream.good() ) {
        lexer.switch_streams(&instream, 0);
    } else if( file == "-" ) {
        lexer.switch_streams(&std::cin, 0);
    } else {
        error ("Cannot open file '" + file + "'.");
        exit (EXIT_FAILURE);
    }
}

void calcxx_driver::scan_end ()
{
    instream.close();
}
