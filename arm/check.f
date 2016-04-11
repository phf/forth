\ Test cases for the FORTH primitives, without jonesforth.f loaded.

\ Test DROP SWAP DUP OVER hacks.
42 43 DROP EMIT
42 43 SWAP EMIT 1 - EMIT
21 DUP + EMIT
1 42 3 OVER EMIT

\ Test ROT and -ROT hacks.
41 42 43 1 - EMIT EMIT 1 + EMIT
41 42 43 ROT 1 + EMIT 1 -  EMIT EMIT
41 42 43 -ROT EMIT 1 + EMIT 1 - EMIT

\ Test 2DROP 2DUP 2SWAP hacks.
42 41 43 2DROP EMIT
42 41 2DUP DROP EMIT DROP EMIT
42 42 41 43 2SWAP EMIT EMIT DROP DROP

\ Test ?DUP hack.
42 ?DUP DROP EMIT
42 0 ?DUP DROP EMIT

\ Test 1+ 1- 4+ 4- hacks.
\ Commented out since they are no longer primitive.
\41 1+ EMIT
\43 1- EMIT
\38 4+ EMIT
\46 4- EMIT

\ Test + - * hacks.
41 1 + EMIT
44 2 - EMIT
11 4 * 2 - EMIT

\ Check /MOD with stars.
120 3 /MOD 2 + EMIT DROP
47 100 /MOD DROP 5 - EMIT

\ Check = <> < > <= >= hacks. (1 = true, 0 = false)
51 52 = 42 + EMIT
52 52 = 41 + EMIT
51 52 <> 41 + EMIT
52 52 <> 42 + EMIT
51 52 < 41 + EMIT
52 52 < 42 + EMIT
52 51 > 41 + EMIT
52 52 > 42 + EMIT
51 52 <= 41 + EMIT
52 52 <= 41 + EMIT
53 52 <= 42 + EMIT
51 52 >= 42 + EMIT
52 52 >= 41 + EMIT
53 52 >= 41 + EMIT

\ Check AND OR XOR INVERT hacks. (bitwise)
1 0 AND 42 + EMIT
1 1 AND 41 + EMIT
234 63 AND EMIT
1 0 OR 41 + EMIT
0 0 OR 42 + EMIT
32 10 OR EMIT
1 0 XOR 41 + EMIT
1 1 XOR 42 + EMIT
226 200 XOR EMIT
0 INVERT 1 AND 41 + EMIT
1 INVERT 1 AND 42 + EMIT
213 INVERT EMIT

\ Marker up to where I am working right now.
124 EMIT

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
