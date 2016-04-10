DONG
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

\ Test 1+ 1- 4+ 4- hacks.
41 1+ EMIT
43 1- EMIT
38 4+ EMIT
46 4- EMIT

\ Test DROP SWAP OVER DUP hacks.
42 43 DROP EMIT
42 43 SWAP EMIT 1- EMIT
21 DUP + EMIT
1 42 3 OVER EMIT

\ Test ROT and -ROT hacks.
41 42 43 1- EMIT EMIT 1+ EMIT
41 42 43 ROT 1+ EMIT 1- EMIT EMIT
41 42 43 -ROT EMIT 1+ EMIT 1- EMIT
