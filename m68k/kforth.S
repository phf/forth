*-----------------------------------------------------------
* Program    : 32 bits Forth System
* Written by : Jean-Denis Koeck
* Date       : June 3th 2009
* Description: minimal Forth implementation in 68k assembly
* Status     : working !
* Todo	     : debugging tools
*-----------------------------------------------------------
	
	OPT	MEX		Expand macro calls
	OPT	SEX		Expand structured statements
	
CODE	EQU	0
DATA	EQU	1
	
CR	EQU	$0D
LF	EQU	$0A
	
_F_HIDDEN EQU	$20
_F_IMMED  EQU	$80
_F_LENGTH EQU	$1F
	
	SECTION DATA
	ORG	$800		set the data adress
	
	SECTION CODE
	ORG	$2000		set the code adress



*-----------------------------------------------------------
* STACK MACROS
*-----------------------------------------------------------

* A7 : return stack pointer
* A6 : parameter stack pointer
* A5 : interpreter pointer

push	MACRO
	move.\0	\1,-(a6)
	ENDM

pop	MACRO
	move.\0	(a6)+,\1
	ENDM

pushrsp	MACRO
	move.l	\1,-(a7)
	ENDM

poprsp	MACRO
	move.l	(a7)+,\1
	ENDM
	
	
	
*-----------------------------------------------------------
* DEFINING WORDS
*-----------------------------------------------------------

defcode	MACRO
* \1	name of the word
* \2	length+flags
* \3	label
* \4	previous word
name_\3
  IFEQ	NARG-3
  	dc.l	0
  ENDC
  IFEQ	NARG-4
	dc.l	name_\4	Link to the previous word
  ENDC
	dc.b	\2,\1,0	Length+flags and word name
\3
  ENDM

defword	MACRO
* \1	name of the word
* \2	length+flags
* \3	label
* \4	previous word
name_\3
	dc.l	name_\4	Link to the previous word
	dc.b	\2,\1,0	Length+flags and word name
\3
	bra	DOCOL
   ENDM



*-----------------------------------------------------------
* INITIALISATION
*-----------------------------------------------------------

START

	move	#50,D0
	trap	#15

	lea  	STACK_TOP,A6	setting up the stack
	lea	COLD_START,A5	setting up the interpreter pointer
	bra	NEXT

	MOVE.B	#9,D0
	TRAP	#15

	STOP	#$2000
	
	SECTION CODE



*-----------------------------------------------------------
* DIRECT THREADING CODE
*-----------------------------------------------------------

* Moves the instruction pointer to the next instruction
* and jumps to the next word
NEXT	move.l	(A5),A0
	adda	#4,A5
	jmp	(A0)

* Saves the current instruction pointer on the rsp
* and jumps to the next word
DOCOL	pushrsp	A5
	adda	#4,A0
	move.l	A0,A5
	bra	NEXT

* Returns from a word
	defcode	'EXIT',$04,EXIT
	poprsp	A5
	bra	NEXT
	


*-----------------------------------------------------------
* BASIC STACK MANIPULATION
*-----------------------------------------------------------

	defcode 'DROP',$04,DROP,EXIT
	adda	#4,A6
	bra	NEXT
	
	defcode 'SWAP',$04,SWAP,DROP
	pop.l	D0
	pop.l	D1
	push.l	D0
	push.l	D1
	bra	NEXT

	* ( a -- a a )
	defcode	<'DUP',0>,$03,DUP,SWAP
	move.l	(A6),D0
	push.l	D0
	bra	NEXT

	* ( a b c -- a b c a )
	defcode	'OVER',$04,OVER,DUP
	move.l	(8,A6),D0
	push.l	D0
	bra	NEXT

	* ( a b c -- c a b )
	defcode	<'ROT',0>,$03,ROT,OVER
	pop.l	D0
	pop.l	D1
	pop.l	D2
	push.l	D0
	push.l	D2
	push.l	D1
	bra	NEXT

	* ( a b c -- b c a ) 
	defcode '-ROT',$04,NROT,ROT
	pop.l	D0
	pop.l	D1
	pop.l	D2
	push.l	D1
	push.l	D0
	push.l	D2
	bra	NEXT
	
	* ( a a -- )
	defcode <'2DROP   '>,$05,TWODROP,NROT
	adda	#8,A6
	bra	NEXT

	* ( a -- a a a )	
	defcode	'2DUP',$04,TWODUP,TWODROP
	move.l	(A6),D0
	push.l	D0
	push.l	D0
	bra	NEXT

	* ( a b c d -- c d a b )
	defcode <'2SWAP   '>,$05,TWOSWAP,TWODUP
	pop.l	D0
	pop.l	D1
	pop.l	D3
	pop.l	D4
	push.l	D1
	push.l	D0
	push.l	D4
	push.l	D3
	bra	NEXT
	
	defcode '?DUP',$04,QDUP,TWOSWAP
	move.l	(A6),D0
	tst.l	D0
	beq	_QDUP
	push	D0
_QDUP	bra	NEXT	


*-----------------------------------------------------------
* INTEGER ARITHMETIC
*-----------------------------------------------------------
	
	defcode <'1+  '>,$02,ONEPLUS,QDUP
	addq.l	#1,(A6)
	bra	NEXT

	defcode	<'1-  '>,$02,ONESUB,ONEPLUS
	subq.l	#1,(A6)
	bra	NEXT
	
	defcode	<'+   '>,$01,PLUS,ONESUB
	pop.l	D0
	add.l	D0,(A6)
	bra	NEXT
	
	defcode <'-   '>,$01,SUB,PLUS
	pop.l	D0
	sub.l	D0,(A6)
	bra	NEXT

	defcode <'*   '>,$01,MUL,SUB
	pop.l	D0
	pop.l	D1
	muls	D1,D0
	push.l	D0
	bra	NEXT


	defcode	'/MOD',$04,DMOD,MUL
	pop.l	D1
	pop.l	D0
	divs	D1,D0
	
	swap	D0
	push.w	D0	push remainder
	push.w	#0
	
	swap	D0
	push.w	D3	push quotient
	push.w	#0
	bra	NEXT
	
	defcode	<'/   '>,$01,DIV,DMOD
	pop.l	D2
	pop.l	D1
	divs	D2,D1
	swap	D1
	clr.w	D1
	swap	D1
	push.l	D1
	bra	NEXT


*-----------------------------------------------------------
* COMPARISON OPERATORS
*-----------------------------------------------------------

	defcode <'=   '>,$01,EQ,DIV
	pop.l	D0
	pop.l	D1
	cmp.l	D0,D1
	beq	_eq
	push.l	#0
	bra	NEXT
_eq	push.l	#1
	bra	NEXT

	defcode	<60,62,0,0>,$02,NEQ,EQ
	pop.l	D0
	pop.l	D1
	cmp.l	D0,D1
	bne	_neq
	push.l	#0
	bra	NEXT
_neq	push.l	#1
	bra	NEXT
	
	defcode	<60,0,0,0>,$01,LT,NEQ
	pop.l	D1
	pop.l	D0
	cmp.l	D1,D0
	blt	_lt
	push.l	#0
	bra	NEXT	
_lt	push.l	#1
	bra	NEXT

	defcode	<62,0,0,0>,$01,GT,LT
	pop.l	D1
	pop.l	D0
	cmp.l	D1,D0
	bgt	_gt
	push.l	#0
	bra	NEXT	
_gt	push.l	#1
	bra	NEXT

	defcode	<60,61,0,0>,$02,LE,GT
	pop.l	D1
	pop.l	D0
	cmp.l	D1,D0
	ble	_le
	push.l	#0
	bra	NEXT	
_le	push.l	#1
	bra	NEXT

	defcode	<62,61,0,0>,$02,GE,LE
	pop.l	D1
	pop.l	D0
	cmp.l	D1,D0
	bge	_ge
	push.l	#0
	bra	NEXT	
_ge	push.l	#1
	bra	NEXT



*-----------------------------------------------------------
* COMPARISON WITH 0
*-----------------------------------------------------------

	defcode <'0=  '>,$02,ZEQ,GE
	pop.l	D0
	cmp.l	#0,D0
	bne	_zeq
	push.l	#0
	bra	NEXT
_zeq	push.l	#1
	bra	NEXT

	defcode	<'0',60,62,0>,$03,ZNEQ,ZEQ
	pop.l	D0
	cmp.l	#0,D0
	beq	_nzeq
	push.l	#0
	bra	NEXT
_nzeq	push.l	#1
	bra	NEXT
	
	defcode	<'0',60,0,0>,$02,ZLT,ZNEQ
	pop.l	D0
	cmp.l	#0,D0
	blt	_zlt
	push.l	#0
	bra	NEXT	
_zlt	push.l	#1
	bra	NEXT

	defcode	<'0',62,0,0>,$02,ZGT,ZLT
	pop.l	D0
	cmp.l	#0,D0
	bgt	_zgt
	push.l	#0
	bra	NEXT	
_zgt	push.l	#1
	bra	NEXT

	defcode	<'0',60,61,0>,$03,ZLE,ZGT
	pop.l	D0
	cmp.l	#0,D0
	ble	_zle
	push.l	#0
	bra	NEXT	
_zle	push.l	#1
	bra	NEXT

	defcode	<'0',62,61,0>,$03,ZGE,ZLE
	pop.l	D0
	cmp.l	#0,D0
	bge	_zge
	push.l	#0
	bra	NEXT	
_zge	push.l	#1
	bra	NEXT



*-----------------------------------------------------------
* LOGICAL OPERATIONS
*-----------------------------------------------------------

	defcode	<'AND '>,$03,AND,ZGE
	pop.l	D0
	and.l	D0,(A6)
	bra	NEXT

	defcode <'OR  '>,$02,OR,AND
	pop.l	D0
	or.l	D0,(A6)
	bra	NEXT
	
	defcode	<'XOR '>,$03,XOR,OR
	pop.l	D0
	eor.l	D0,(A6)
	bra	NEXT
	
	defcode	<'INVERT  '>,$06,INVERT,XOR
	not.l	(A6)
	bra	NEXT
	
	defcode	<'ALIGNED '>,$7,ALIGNED,INVERT
	move.l	var_HERE,D0
	addq	#3,D0		round up length 
	andi	#~3,D0		... to next 4 bytes boundary
	move.l	D0,var_HERE	store
	bra	NEXT

	
*-----------------------------------------------------------
* LITERALS
*-----------------------------------------------------------

	defcode	<'LIT '>,$03,LIT,ALIGNED
	move.l	A5,A0
	adda	#4,A5
	push.l	(A0)
	bra	NEXT



*-----------------------------------------------------------
* MEMORY
*-----------------------------------------------------------

	defcode	<'!   '>,$01,STORE,LIT
	pop.l	A0
	pop.l	D0
	move.l	D0,(A0)
	bra	NEXT

	defcode	<'@   '>,$01,FETCH,STORE
	pop.l	A0
	push.l	(A0)
	bra	NEXT
		
	defcode	<'+!  '>,$02,ADDSTORE,FETCH
	pop.l	A0
	pop.l	D0
	add.l	D0,(A0)
	bra	NEXT
	
	defcode	<'-!  '>,$02,SUBSTORE,ADDSTORE
	pop.l	A0
	pop.l	D0
	sub.l	D0,(A0)
	bra	NEXT
		
	defcode	<'C!  '>,$02,STOREBYTE,SUBSTORE
	pop.l	A0
	pop.l	D0
	move.b	D0,(A0)
	bra	NEXT
	
	defcode	<'C@  '>,$02,FETCHBYTE,STOREBYTE
	pop.l	A0
	clr.l	D0
	move.b	(A0),D0
	push.l	D0
	bra	NEXT
	


*-----------------------------------------------------------
* BUILT-IN VARIABLES
*-----------------------------------------------------------

defvar	MACRO
* \0	variable size
* \1	name
* \2	length+flags
* \3	label
* \4	previous word
* \5	initial value

	SECTION	DATA

var_\3
  IFEQ	NARG-4
  	dc.\0	0
  ENDC
  IFEQ	NARG-5
	dc.\0	\5	Initial value
  ENDC
  
  	SECTION CODE
name_\3
	dc.l	name_\4	Link to the previous word
	dc.b	\2,\1,0	Length+flags and word name
\3
	lea	var_\3,A0
	push.\0	A0
	bra	NEXT
	ENDM
	
* STATE		Is the interpreter executing code (0) or compiling a word (non-zero)?
* LATEST	Points to the latest (most recently defined) word in the dictionary.
* HERE		Points to the next free byte of memory.  When compiling, compiled words go here.
* S0		Stores the address of the top of the parameter stack.
* BASE		The current base for printing and reading numbers.
	
	defvar.l <'STATE   '>, $05, STATE,  FETCHBYTE
	defvar.l 'HERE',       $04, HERE,   STATE,    _HERE
	defvar.l <'LATEST  '>, $06, LATEST, HERE,     name_RES_FETCH
	defvar.l <'S0  '>,     $02, SZ,     LATEST,   STACK_TOP
	defvar.l 'BASE',       $04, BASE,   SZ,       10



*-----------------------------------------------------------
* BUILT-IN CONSTANTS
*-----------------------------------------------------------

defconst MACRO
* \0	 constant size
* \1	 name
* \2	 length+flags
* \3	 label
* \4	 previous word
* \5	 value
name_\3
	dc.l	name_\4		Link to the previous word
	dc.b	\2,\1,0		Length+flags and word name
\3
	push.\0	\5
	bra	NEXT
  ENDM

* VERSION	Is the current version of this FORTH.
* R0		The address of the top of the return stack.
* DOCOL		Pointer to DOCOL.
* F_IMMED	The IMMEDIATE flag's actual value.
* F_HIDDEN	The HIDDEN flag's actual value.
* F_LENGTH	The length mask in the flags/len byte.

	defconst.l <'VERSION '>,    $07, VERSION,  BASE,     #5
	defconst.l <'R0  '>,        $02, RZ,       VERSION,  #STACK_TOP
	defconst.l <'F_IMMED '>,    $07, F_IMMED,  RZ,       _F_IMMED
	defconst.l <'F_HIDDEN'>,    $08, F_HIDDEN, F_IMMED,  _F_HIDDEN
	defconst.l <'F_LENGTH'>,    $08, F_LENGTH, F_HIDDEN, _F_LENGTH



*-----------------------------------------------------------
* RETURN STACK
*-----------------------------------------------------------
*       >R
	defcode	<62,'R  '>, $02, TOR, F_LENGTH
	pop.l	D0
	pushrsp	D0
	bra	NEXT

*	R>
	defcode <'R',62,'  '>, $02, FROMR, TOR
	poprsp	D0
	push.l	D0
	bra	NEXT
	
	defcode 'RSP@', $04, RSPFETCH, FROMR
	push.l	A7
	bra	NEXT

	defcode	'RSP!', $04, RSPSTORE, RSPFETCH
	pop.l	(A7)
	bra	NEXT

	defcode	<'RSPDROP '>, $07, RSPDROP, RSPSTORE
	adda	#4,A7
	bra	NEXT



*-----------------------------------------------------------
* PARAMETER STACK
*-----------------------------------------------------------

	defcode 'DSP@', $04, DSPFETCH, RSPDROP
	push.l	A6
	bra	NEXT
	
	defcode	'DSP!', $04, DSPSTORE, DSPFETCH
	pop.l	(A6)
	bra	NEXT
	


*-----------------------------------------------------------
* READING INPUT
*-----------------------------------------------------------
	
	
	defcode	'EMIT',$04,EMIT,DSPSTORE
	pop.l	D1
	move.b	#6,D0	Easy 68K trap
	trap	#15	Displays the character on the screen
	bra	NEXT
	
	
	defcode	<'KEY',0>,$03,KEY,EMIT
	clr.l	D1
	bsr	_KEY
	push.l	D1
	bra	NEXT

	SECTION DATA
BUFFER_SIZE equ	4096
BUFFER	ds.b	BUFFER_SIZE	Static input buffer
CURRKEY	dc.l	BUFFER		Current position
BUFFTOP	dc.l	BUFFER		Buffer top

* Stream number (1 == stdin, otherwise file_id)
INPUT_STREAM
	dc.l	$FFFFFFFF

	SECTION CODE

_KEY	
	move.l	CURRKEY,A0
	move.l	BUFFTOP,A1
	cmp.l	A0,A1
	ble	more_input
	
	clr	D1
	move.b	(A0)+,D1
	move.l	A0,(CURRKEY)
	rts
	
more_input
	move.l	INPUT_STREAM,D1
	cmp.l	#$FFFFFFFF,D1
	beq	more_input_stdin
	bra	more_input_file
	
more_input_stdin
	lea	BUFFER,A1
	lea	BUFFER,A0
	
	move.b	#2,D0		Easy 68k trap
	trap	#15		Read into the buffer, D1 <- nb chars read
	
	adda	D1,A1
	move.b	#$0A,(A1)+
	
	move.l	A1,BUFFTOP	BUFFTOP   <- buffer + nb characters read
	move.l	A0,CURRKEY
	
	bra	_KEY
	
more_input_file

	lea	BUFFER,A1
	lea	BUFFER,A0

	move	#4096,D2
	move	#53,D0
	trap	#15		D2 <- nb of bytes read

*	If error, redirect stream
	cmp.w	#0,D0
	bne	redirect

continue_file
	adda	D2,A1
	
	move.l	A1,BUFFTOP	BUFFTOP   <- buffer + nb characters read
	move.l	A0,CURRKEY
	bra	_KEY
	
redirect
*	Close the file
	move.l	INPUT_STREAM,D1
	move	#56,D0
	trap	#15
	
	move.l	#$FFFFFFFF,INPUT_STREAM
	
	move.l	A0,CURRKEY
	move.l	A0,BUFFTOP
	bra	_KEY

	defcode <'WORD'>,$04,WORD,KEY
	bsr	_WORD
	push.l	A1		push adress
	push.l	A2		push length
	bra	NEXT

_WORD
* Reads the input with _KEY
* Returns the string adress in A1
*         the string length in A0

* Search for the first non-whitespace character
* Skip line comments (beginning with '\')
white	bsr	_KEY
	cmp	#' ',D1
	beq	white
	cmp	#CR,D1
	beq	white
	cmp	#LF,D1
	beq	white
	cmp	#9,D1
	beq	white
	
	lea	WORD_BUFFER,A2
	
* Searches for the end of the word
* Stores characters in the buffer
write	cmp.b	#'\',D1
	beq	skip
	
	cmp	#' ',D1
	beq	END_WORD
	cmp	#CR,D1
	beq	END_WORD
	cmp	#LF,D1
	beq	END_WORD
	cmp	#9,D1
	beq	END_WORD
	
	move.b	D1,(A2)+
	bsr	_KEY
	bra	write

* Skips line comment until CR	
skip	bsr	_KEY
	cmp.b	#CR,D1
	beq	white
	cmp.b	#LF,D1
	beq	white
	bra	skip
	
END_WORD
	lea	WORD_BUFFER,A1	A1 <- static buffer adress
	suba	A1,A2		A2 <- string length
	rts

* Static buffer
	SECTION DATA
WORD_BUFFER
	ds.b	32

	SECTION CODE
	
	defcode	'char',$04,CHAR,WORD
	bsr	_WORD		A1 <- adress, A2 <- length
	clr	D0
	move.b	(A1),D0
	push.l	D0
	bra	NEXT


*-----------------------------------------------------------
* READING/PRINTING NUMBERS
*-----------------------------------------------------------


	defcode	<'NUMBER  '>,$06,NUMBER,CHAR
	pop.l	D0	string length
	pop.l	A0	string adress
	bsr	_NUMBER
	push.l	D3	parsed number
	push.l	D0	number of unparsed characters (0 if no error)
	bra	NEXT
	
_NUMBER
	clr.l	D3
	clr.l	D4
	clr.l	D2
	
	tst.l	D0
	beq	parse_end
	
	move.l	var_BASE,D1
	move.b	(A0)+,D2
*	push.l	D3		push 0
	
	cmp	#'-',D2
	bne	convert
	
minus	move.b	#1,MINUS_F
	subq	#1,D0
	tst	D0
	bne	read_digits
*	error : the string is "-"
	move	#1,D0
	rts

* Loop reading digits
read_digits
	muls	D1,D3
	move.b	(A0),D2
	addq	#1,A0

* Convert 0-9 and A-Z to 0-35
convert	sub.b	#'0',D2
	cmp.b	#0,D2
	blt	parse_exit	< '0' ?
	
	cmp.b	#10,D2
	blt	is_number	< '10' ?
	
	sub.b	#17,D2	
	cmp.b	#0,D2		< 'A' ? (D2 - '0' - 17 == D2 - 'A')
	blt	parse_exit
	
	add.b	#10,D2

is_number
	cmp	D1,D2		>= BASE ?
	bge	parse_exit
	
	add.l	D2,D3
	sub	#1,D0
	cmp	#0,D0
	bne	read_digits	
	
parse_exit
	move.b	MINUS_F,D2
	cmp.b	#0,D2
	beq	parse_end
	
	move.b	#0,MINUS_F
	neg.l	D3
	
parse_end
	rts

	SECTION DATA
MINUS_F	dc.b	0

	SECTION CODE

	defcode	<'.   '>,$01,DOT,NUMBER	
	pop.l	D1
	move.l	var_base,D2
	cmp.l	#10,D2		decimal ?
	bne	not_decimal
	
decimal
	move.b	#3,D0
	trap	#15
	bra	new_line

not_decimal	
	move.b	#15,D0
	trap	#15
	
new_line
	move.b	#6,D0	
	move.b	#$0A,D1
	trap	#15
	move.b	#$0D,D1
	trap	#15
	bra	NEXT

*-----------------------------------------------------------
* FINDING WORDS
*-----------------------------------------------------------

	defcode	'FIND',$04,FIND,DOT
	pop.l	D0		length of the word name
	pop.l	A0		word name adress
	bsr	_FIND
	push.l	A1		push the adress (NULL if not found)
	bra	NEXT
	
_FIND	lea	var_LATEST,A1

* _FIND	lea	NAME_FIND,A1	latest word
	
_find_	cmp	#0,A1		null pointer ?
	beq	_null		give up
	
* compares string lengths
length	move.b	(4,A1),D1	D1 <- candidate length
	andi.b	#$3F,D1
	cmp	D0,D1
	bne	to_next
	
* same string lengths, compares the strings
	movea	A0,A2		A2 <- word name
	lea	(5,A1),A3	A3 <- candidate name
	subq	#1,D1
	
loop	*We could do the following
	* cmp.b	(A2)+,(A3)+	different characters ?
	*But this interpreter is case insensitive
	
	move.b	(A2)+,D2
	bsr	to_uppercase
	move.b	D2,D3
	
	move.b	(A3)+,D2
	bsr	to_uppercase
	

	cmp.b	D2,D3
	
	bne	to_next		then next candidate
	dbra	D1,loop
	
* same strings !
	rts

to_next	move.l	(A1),A1
	bra	_find_

* giving up, returns NULL	
_null	movea 	#0,A1		a1 <- null
	rts
	
to_uppercase
* let f c = if int_of_char c >= 97 && int_of_char c <= 122 then char_of_int (int_of_char c - 32) else c
	cmp.b	#97,D2
	blt	_end
	cmp.b	#122,D2
	bgt	_end
	
	* 97 <= D3 <= 122
	sub.b	#32,D2
	
_end	rts

	defcode <62,'DFA'>,$04,TDFA,FIND
	pop.l	A0
	bsr	_TDFA
	push.l	A0
	bra	NEXT
	
_TDFA	clr	D0
	move.b	(4,A0),D0
	addq	#3,D0
	andi	#~3,D0
	andi.b	#_F_LENGTH,D0
	add	D0,A0
	adda	#6,A0
	rts



*-----------------------------------------------------------
* COMPILING
*-----------------------------------------------------------

* CREATES creates a header for a new word

	defcode	<'CREATE  '>,$06,CREATE,TDFA
	
	* Get name adress and name length
	pop.l	D0	length
	pop.l	A0	adress
	move.l	D0,D1
	
	* Get and write link pointer
	move.l	var_HERE,A1
	move.l	(var_LATEST),(A1)+
	
	* Write length/byte flag
	move.b	D0,(A1)+
	
	* write name
	move.l	A1,A2
write_loop
	move.b	(A0)+,(A2)+
	dbf	D0,write_loop
	
	* align length to 4 byte boundary
	addq	#3,D1
	andi	#~3,D1
	adda	D1,A1
	addq	#1,A1
	
	* update latest and here
	move.l	VAR_HERE,VAR_LATEST
	move.l	A1,VAR_HERE
	
	bra	NEXT


* COMMA appends codewords to the word being compiled

	defcode	<',   '>,$01,COMMA,CREATE
	pop.l	D0
	bsr	_COMMA
	bra	NEXT

_COMMA	move.l	var_HERE,A0
	move.l	D0,(A0)+
	move.l	A0,VAR_HERE
	rts
	
* Word	Assembler	Action		Effect
* [	LBRAC		STATE := 0	Switch to immediate mode.
* ]	RBRAC		STATE := 1	Switch to compile mode.

	defcode	<'[   '>,$81,LBRAC,COMMA
	move.l	#0,(var_STATE)
	bra	NEXT
	
	defcode	<']   '>,$81,RBRAC,LBRAC
	move.l	#1,(var_STATE)
	bra	NEXT

* BRADOCOL appends an instruction that has the effect "bra DOCOL" at var_here
	defcode 'BRADOCOL',$08,BRADOCOL,RBRAC
	lea	DOCOL,A0
	move.l	var_HERE,A1
	suba	A1,A0
	suba	#2,A0
	move.l	var_HERE,A2
	move.w	#$6000,(A2)+
	move.w	A0,(A2)+
	move.l	A2,var_HERE
	bra	NEXT
	
* COLON defines a new word
	
	defword	<':   '>,$01,COLON,BRADOCOL
	dc.l	WORD			find next word
	dc.l	CREATE			create word header
	dc.l	BRADOCOL		append docol
	dc.l	LATEST,FETCH,HIDDEN	hide the word
	dc.l	RBRAC			compile mode
	dc.l	EXIT			return from the word


* SEMICOLON ends the definition of a new word

	defword <';   '>,$81,SEMICOLON,COLON
	dc.l	LIT,EXIT,COMMA		append exit
	dc.l	LATEST,FETCH,HIDDEN	de-hide the new word
	dc.l	LBRAC			return to immediate mode
	dc.l	EXIT			return from the word


* "adress HIDDEN" toggles the hidden flag on the word adress

	defcode <'HIDDEN  '>,$05,HIDDEN,SEMICOLON
	pop.l	A0		get the adress
	adda	#4,A0		point to the flags/length header byte
	move.b	(A0),D0		D0 <- flags/length byte
	eor.b	#_F_HIDDEN,D0	toggle hidden bit
	move.b	D0,(A0)		back in memory
	bra	NEXT

	
* "word HIDE" toggle the hidden flag in "word"
	defword	<'HIDE'>,$04,HIDE,HIDDEN
	dc.l	WORD,FIND,HIDDEN	get word, get adress and toggle
	dc.l	EXIT
	
	
* TICK returns the codeword pointer of the next word
	defcode <39,'   '>,$01,TICK,HIDE
	move.l	A5,A0
	adda	#4,A5
	push.l	(A0)
	bra	NEXT

* IMMEDIATE renders a word immediate
	defcode	<'IMMEDIATE   '>,$89,IMMEDIATE,TICK
	move.l	var_LATEST,A0
	adda.l	#4,A0
	eori.b	#_F_IMMED,(A0)
	bra	NEXT
	

*-----------------------------------------------------------
* BRANCHING
*-----------------------------------------------------------

* BRANCH adds an offset to the instruction pointer
	defcode	<'BRANCH  '>,$06,BRANCH,IMMEDIATE
	adda.l	(A5),A5
	bra	NEXT
	
	
* 0BRANCH adds an offset if the top of stack is non-zero
	defcode	<'0BRANCH '>,$07,0BRANCH,BRANCH
	pop.l	D0
	tst.l	D0
	beq	BRANCH		if non-zero, call branch
	adda	#4,A5		otherwise skip the offset
	bra	NEXT

	
*-----------------------------------------------------------
* LITERAL STRINGS
*-----------------------------------------------------------

	defcode	<'LITSTRING   '>,$09,LITSTRING,0BRANCH
	move.l	(A5),D0		get string length
	adda	#4,A5
	push.l	A5		push string adress
	push.l	D0		push string length
	addq	#3,D0		round up length 
	andi	#~3,D0		... to next 4 bytes boundary
	adda	D0,A5		add length to interpreter pointer
	bra	NEXT

	defcode	<'TELL'>,$04,TELL,LITSTRING
	pop.l	D1		get string length
	pop.l	A1		get string adress
	move.b	#1,D0		display string in easy68k
	trap	#15
	bra	NEXT
	

*-----------------------------------------------------------
* INTERPRETING
*-----------------------------------------------------------

* QUIT does some initialisation and calls INTERPRET
	
	defword	<'QUIT'>,$04,QUIT,TELL
	dc.l	RZ,RSPSTORE	clear stack pointer
	dc.l	INTERPRET	call the interpreter
	dc.l	BRANCH,-8	loop forever


	defcode	<'INTERPRET   '>,$09,INTERPRET,QUIT
	bsr	_WORD		A1 <- string adress, A2 <- string length

	clr.l	D0
	clr.l	D3
	move.b	D0,READING_LIT
	push.l	A1		save string adress
	push.l	A2		save string length
	
*	lea	READING_LIT,A3	A3 <- READING_LIT adress

	move.l	A1,A0		preparing the call
	move.l	A2,D0		... to FIND
	bsr	_FIND		A1 <- word adress
	cmp.l	#0,A1		found ?
	beq	literal
	
*	Word in dictionary
	adda	#8,A6
	move.l	A1,A0		A0 <- word adress
	adda	#4,A1		A1 <- length/byte flag adress
	bsr	_TDFA		A0 <- data field adress
	move	A0,D0
	
	move.b	(A1),D1		D1 <- length/byte flag
	andi.b	#_F_IMMED,D1	D1 <- immediate ?
	
	tst.b	D1
	bne	execute		immediate, execute the word
	bra	append		otherwise, append the word

*	Word not in dictionary, assume it is a literal
literal	move.b	#1,READING_LIT
	pop.l	D0		D0 <- string length
	pop.l	A0		A0 <- string adress
	bsr	_NUMBER		D3 <- parsed number, D0 <- nb of unparsed chars
	
	tst	D0
	bne	parse_error
	
*	No parse error
	move	#LIT,D0		A0 <- LIT adress
	
*	Compilig or executing ?
* STATE	: 0 -> executing code, non-zero -> compiling a word
append	move.l	var_STATE,D2
	tst	D2		compiling or executing ?
	beq	execute
	
*	Append the codeword
	bsr	_COMMA

*	Were we compiling a literal ?
	move.b	READING_LIT,D4		D4 <- READING_LIT
	tst.b	D4
	beq	interp_end	if not, all done
	
*	If so, append it and all done
	move.l	D3,D0
	bsr	_COMMA

interp_end
	bra	NEXT

*	Run the current word
execute
	move.b	READING_LIT,D4
	tst	D4		executing literal ?
	bne	exec_lit

* 	Not a literal, run the word
	jmp	(A0)

*	Executing a literal, which means pushing it on the stack
exec_lit
	push.l	D3
	bra	NEXT
	
* 	Parse error
*	TODO : print an error
*	quits the interpreter for the moment
parse_error
	lea	ERROR,A1
	move	#11,D1
	move.b	#0,D0
	trap	#15
	bra	NEXT

	SECTION	DATA
READING_LIT
	ds.b	1
ERROR
	dc.b	'PARSE ERROR'
	
	SECTION CODE

*-----------------------------------------------------------
* INTERPRETING KFORTH.F
*-----------------------------------------------------------

	SECTION DATA
KFORTH
	dc.b	'kforth.f',0
KFORTH_CHARS
	dc.b	'kforth-chars',0
	
	SECTION CODE
	
	defcode	<'reload  '>,$06,RELOAD,INTERPRET
	lea	KFORTH,A1
	move	#51,D0
	trap	#15		D1 <- file_if
	move.l	D1,INPUT_STREAM
	bra	NEXT


*-----------------------------------------------------------
* MISCELLANEOUS
*-----------------------------------------------------------

	defcode	<'wait'>,$04,WAIT,RELOAD
	pop.l	D1
	move.b	#23,D0
	trap	#15
	bra	NEXT

	defcode	<'hardware'>,$08,HARDWARE,WAIT
	move.b	#0,D1
	move.b	#32,D0
	trap	#15
	bra	NEXT
	
	
*-----------------------------------------------------------
* GRAPHICS
*-----------------------------------------------------------

	defcode	<'clear   '>,$05,CLEAR,HARDWARE
	move.w	#$FF00,D1
	move.b	#11,D0
	trap	#15
	bra	NEXT
	
	defcode	<'rgb '>,$03,RGB,CLEAR
	bsr	_RGB
	push.l	D1
	bra	NEXT
	
_RGB
	pop.l	D3
	pop.l	D2
	pop.l	D1
	lsl.l	#8,D2
	lsl.l	#8,D3
	lsl.l	#8,D3
	add.l	D2,D1
	add.l	D3,D1
	move.b	#80,D0
	trap	#15
	rts
	
	defcode	<'pen!'>,$04,PEN,RGB
	pop.l	D1
	move.b	#80,D0
	trap	#15
	bra	NEXT
	
	defcode	<'fill!   '>,$05,FILL,PEN
	pop.l	D1
	move.b	#81,D0
	trap	#15
	bra	NEXT

	defcode	<'pixel   '>,$05,PIXEL,FILL
	pop.l	D1
	pop.l	D2
	move.b	#82,D0
	trap	#15
	bra	NEXT
	
	defcode	<'pixel@  '>,$06,PIXEL_GET,PIXEL
	pop.l	D1
	pop.l	D2
	move.b	#83,D0
	trap	#15
	bra	NEXT
	
	defcode <'line'>,$04,LINE,PIXEL_GET
	pop.l	D4
	pop.l	D3
	pop.l	D2
	pop.l	D1
	move.b	#84,D0
	trap	#15
	bra	NEXT
	
	defcode <'line-from-pen   '>,$0D,LINE_FROM_PEN,LINE
	pop.l	D2
	pop.l	D1
	move.b	#85,D0
	trap	#15
	bra	NEXT
	
	defcode <'move'>,$04,MOVE,LINE_FROM_PEN
	pop.l	D2
	pop.l	D1
	move.b	#86,D0
	trap	#15
	bra	NEXT
	
	defcode <'rect'>,$04,RECT,MOVE
	pop.l	D4
	pop.l	D3
	pop.l	D2
	pop.l	D1
	move.b	#87,D0
	trap	#15
	bra	NEXT
	
	defcode <'ellipse '>,$07,ELLIPSE,RECT
	pop.l	D4
	pop.l	D3
	pop.l	D2
	pop.l	D1
	move.b	#88,D0
	trap	#15
	bra	NEXT
	
	defcode <'flood-fill  '>,$0A,FLOOD_FILL,ELLIPSE
	pop.l	D2
	pop.l	D1
	move.b	#89,D0
	trap	#15
	bra	NEXT
	
	defcode <'u-rect  '>,$06,UNFILLED_RECT,FLOOD_FILL
	pop.l	D4
	pop.l	D3
	pop.l	D2
	pop.l	D1
	move.b	#90,D0
	trap	#15
	bra	NEXT
	
	defcode <'u-ellipse   '>,$09,UNFILLED_ELLIPSE,UNFILLED_RECT
	pop.l	D4
	pop.l	D3
	pop.l	D2
	pop.l	D1
	move.b	#91,D0
	trap	#15
	bra	NEXT
	
	defcode <'pen-width!  '>,$0A,PEN_WIDTH,UNFILLED_ELLIPSE
	pop.l	D1
	move.b	#93,D0
	trap	#15
	bra	NEXT
	
	defcode <'res!'>,$04,RES_STORE,PEN_WIDTH
	pop.l	D2
	pop.l	D1
	swap	D1	high word <- height
	move.w	D2,D1	low  word <- width
	move.b	#33,D0
	trap	#15
	bra	NEXT
	
	defcode <'res@'>,$04,RES_FETCH,RES_STORE
	clr	D1
	move.b	#33,D0	high <- width
	trap	#15	low  <- height
	push.w	D1	push height
	push.w	#0
	swap	D0
	push.w	D1	push width
	push.w	#0
	bra	NEXT


*-----------------------------------------------------------
* DATA
*-----------------------------------------------------------
	
	SECTION DATA

* STACK MEMORY
STACK	ds.l	32
STACK_TOP

COLD_START
	dc.l	RELOAD
	dc.l	QUIT
	
	SECTION CODE
* Memory for new words, strings, arrays...
_HERE	ds.l 	10240

	END	START





*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~

<!-- Page not cached by WP Super Cache. No closing HTML tag. Check your theme. -->
