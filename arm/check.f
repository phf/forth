\ Test cases for the basic FORTH interpreter, without jonesforth.f loaded.

\ A word that puts 42 on the stack.
: FORTYTWO 41 1 + ;

\ A word that prints an asterisk.
: STAR FORTYTWO EMIT ;

\ Actually print one.
STAR

\ Double value on stack.
: DOUBLE DUP + ;

\ Quadruple value on stack.
: QUADRUPLE DOUBLE DOUBLE ;

\ Try those two.
10 QUADRUPLE 2 + EMIT

\ Check /MOD with stars.
120 3 /MOD 2 + EMIT
47 100 /MOD DROP 5 - EMIT
