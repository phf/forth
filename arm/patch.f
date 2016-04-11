\ The following used to be primitives in the original jonesforth.S but
\ I decided to replace with "library code" as it were. This file needs
\ to be prefixed to jonesforth.f for things to work out (see Makefile).

: 0= 0 = ;
: 0> 0 > ;
: 0< 0 < ;
: 0<> 0 <> ;
: 0<= 0 <= ;
: 0>= 0 >= ;

: 1+ 1 + ;
: 1- 1 - ;
: 4+ 4 + ;
: 4- 4 - ;

: >DFA >CFA 4+ ;

: HIDE WORD FIND HIDDEN ;
