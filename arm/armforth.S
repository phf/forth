@ armforth.S - Porting Richard Jones' FORTH to ARM
@
@ Copyright (c) 2010 by Peter H. Froehlich <phf@acm.org>
@ All right reserved.
@
@ Please read Richard's original version if you want
@ the whole tutorial about FORTH. I'll just mention
@ some ARM related stuff here.
@
@ Eventually there will be some kind of license here.

	.set JONES_VERSION,47
	.set ARM_VERSION,0

@ ARM ABI conventions
@ ===================
@
@ It's ridiculously complicated to find the exact ABI
@ details for Linux on ARM. Someone should really sit
@ down with all the kernel sources, lots of coke, and
@ then document them all.
@
@ Until proven wrong, I'll assume that Linux adheres
@ to most of the "official" ABI specification, which
@ roughly states the following:
@
@	register	aliases		notes
@
@	r15		pc		program counter
@	r14		lr		link register
@	r13		sp		stack pointer
@	r12		ip		linker scratch
@	r11		v8		variable
@	r10		v7		variable
@	r9		v6/sb/tr	variable/platform special
@	r8		v5		variable
@	r7		v4		variable/EABI special*
@	r6		v3		variable
@	r5		v2		variable
@	r4		v1		variable
@	r3		a4		argument/scratch
@	r2		a3		argument/scratch
@	r1		a2		argument/result/scratch
@	r0		a1		argument/result/scratch
@
@ *ARM Linux EABI uses r7 for the system call number,
@  making r7 "special" too. :-/
@ 
@ Registers v1-v8 and sp are callee-saved, except of
@ course if they are "special". Registers a1-a4 and lr
@ seem to be caller-saved by implication.
@
@ ARMFORTH conventions
@ ====================
@
@ From the mess above we derive the following register
@ conventions for FORTH:
@
@	register	mnemonic	notes
@
@	r13/sp		PSP		parameter stack pointer
@	r11/v8		RSP		return stack pointer
@	r10/v7		NIP		next instruction pointer
@	r4-r6,r8	S0-S3		callee saved temporaries
@	r0-r3		T0-T3		caller saved temporaries
@
@ We simply try to stay clear of all the "special" stuff,
@ which still leaves us with enough room to play. The S?
@ and T? mnemonics are inspired by MIPS of course.
@
@ Notes
@ =====
@
@ .align for x86 is bytes, for ARM it's powers of two
@
@ TODO
@ ====
@
@ can we use load/store multiple to our advantage?

@ for some reason .set doesn't seem to work for this

#define PSP r13
#define RSP r11
#define NIP r10
#define T0  r0
#define T1  r1
#define T2  r2
#define T3  r3
#define S0  r4
#define S1  r5
#define S2  r6
#define S3  r8

	.set	stdin,0
	.set	stdout,1
	.set	stderr,2

	.macro NEXT
	bl	debug_ping
	ldr	T0, [NIP], #4		@ load codeword address from NIP, increment
	bx	T0			@ jump to codeword
	.endm

	.macro PUSHRSP reg
	str	\reg, [RSP, #-4]!	@ store register into RSP-4, decrement
	.endm

	.macro POPRSP reg
	ldr	\reg, [RSP], #4		@ load register from RSP, increment
	.endm

	.macro PUSHPSP reg
	str	\reg, [PSP, #-4]!	@ store register into PSP-4, decrement
	.endm

	.macro POPPSP reg
	ldr	\reg, [PSP], #4		@ load register from PSP, increment
	.endm


	.text
	.align 2
	@ We get here only from NEXT, so T0 is guaranteed to be the codeword
	@ for DOCOL itself.
DOCOL:
	PUSHRSP	NIP		@ push NIP on return stack
	add	T0, T0, #4	@ add 4 to codeword to get first dataword
	mov	NIP, T0		@ make first dataword the NIP
	NEXT


	.text
	.global _start
_start:
	ldr	T0, =var_S0		@ address of var_S0
	str	PSP, [T0]		@ store initial PSP in var_S0
	ldr	RSP, =return_stack_top	@ initialize return stack
	bl	set_up_data_segment
	ldr	NIP, =cold_start	@ initialize interpreter
	NEXT
	.pool

	.section .rodata
cold_start:
	.int QUIT


	.set F_IMMED,0x80
	.set F_HIDDEN,0x20
	.set F_LENMASK,0x1f

	.set link,0

	.macro defword name, namelen, flags=0, label
	.section .rodata
	.align 2
	.global name_\label
name_\label :
	.int link
	.set link,name_\label
	.byte \flags+\namelen
	.ascii "\name"
	.align 	2
	.global \label
\label :
	.int DOCOL
	@ list of word pointers follows
	.endm

	.macro defcode name, namelen, flags=0, label
	.section .rodata
	.align 2
	.global name_\label
name_\label :
	.int link
	.set link,name_\label
	.byte \flags+\namelen
	.ascii "\name"
	.align 2
	.global \label
\label :
	.int code_\label
	.text
	.global code_\label
code_\label :
	@ assembler code follows
	.endm


	defcode "DROP",4,,DROP
	add PSP, PSP, #4	@ POPPSP would load from memory
	NEXT

	defcode "SWAP",4,,SWAP
	POPPSP	T0		@ TODO: avoid unnecessary PSP updates
	POPPSP	T1
	PUSHPSP	T0
	PUSHPSP	T1
	NEXT

	defcode "DUP",3,,DUP
	ldr	T0, [PSP]	@ POPPSP would require two PUSHPSPs
	PUSHPSP	T0
	NEXT

	defcode "OVER",4,,OVER
	ldr	T0, [PSP, #4]
	PUSHPSP	T0
	NEXT

	defcode "ROT",3,,ROT
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	POPPSP	T2
	PUSHPSP	T1
	PUSHPSP	T0
	PUSHPSP	T2
	NEXT

	defcode "-ROT",4,,NROT
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	POPPSP	T2
	PUSHPSP	T0
	PUSHPSP	T2
	PUSHPSP	T1
	NEXT

	defcode "2DROP",5,,TWODROP
	add	PSP, PSP, #8	@ POPPSP would load from memory
	NEXT

	defcode "2DUP",4,,TWODUP
	ldr	T0, [PSP]	@ POPPSP would require two PUSHPSPs
	ldr	T1, [PSP, #4]	@ same
	PUSHPSP	T1
	PUSHPSP	T0
	NEXT

	defcode "2SWAP",5,,TWOSWAP
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	POPPSP	T2
	POPPSP	T3
	PUSHPSP	T1
	PUSHPSP	T0
	PUSHPSP	T3
	PUSHPSP	T2
	NEXT

	defcode "?DUP",4,,QDUP
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	cmp	T0, #0		@ != 0?
	strne	T0, [PSP, #-4]!	@ PUSHPSP is not conditional
	NEXT

	defcode "1+",2,,INCR
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	add	T0, T0, #1
	str	T0, [PSP]
	NEXT

	defcode "1-",2,,DECR
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	sub	T0, T0, #1
	str	T0, [PSP]
	NEXT

	defcode "4+",2,,INCR4
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	add	T0, T0, #4
	str	T0, [PSP]
	NEXT

	defcode "4-",2,,DECR4
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	sub	T0, T0, #4
	str	T0, [PSP]
	NEXT

	defcode "+",1,,ADD
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	add	T0, T1, T0
	PUSHPSP	T0
	NEXT

	defcode "-",1,,SUB
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	sub	T0, T1, T0
	PUSHPSP	T0
	NEXT

	defcode "*",1,,MUL
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	mul	T0, T1, T0
	PUSHPSP	T0
	NEXT



	defcode "/MOD",4,,DIVMOD
	POPPSP	T0		@ dividend?
	POPPSP	T1		@ divisor?
	bl	_DIVMOD
	PUSHPSP	T0		@ remainder
	PUSHPSP	T1		@ quotient
	NEXT
_DIVMOD:
	@ DIVMOD (x: T0, y: T1) (q: T0, r: T1)
	stmfd	sp!, {S0, S1}

	@ if signs differ, we need to negate the quotient later
	eors	S0, T0, T1
	movmi	S0, #1		@ yes we should negate
	movpl	S0, #0		@ no we are fine

	@ absolute values for division algorithm
	cmp	T0, #0
	rsbmi	T0, T0, #0
	cmp	T1, #0
	rsbmi	T1, T1, #0

	mov	T2, #0		@ quotient q
	mov	T3, T1		@ remainder r
	mov	S1, T0		@ old divisor y

1:	@ shift divisor
	cmp	T1, T0		@ y <= x
	movle	T1, T1, LSL #1	@ y = y * 2
	ble	1b

2:	@ perform division
	cmp	T1, S1		@ y != old y
	beq	3f		@ done
	mov	T1, T1, LSR #1	@ y = y / 2
	mov	T2, T2, LSL #1	@ q = q * 2
	cmp	T3, T1		@ r >= y
	subge	T3, T3, T1	@ r = r - y
	addge	T2, T2, #1	@ q = q + 1
	b	2b
3:
	@ now T2 quotient T3 remainder
	cmp	S0, #0		@ initial signs differed?
	rsbne	T2, T2, #0	@ negate quotient!

	mov	T0, T2
	mov	T1, T3

	ldmfd	sp!, {S0, S1}
	bx	lr



@ TODO: register names inconsistent from here on out

	@ use 1 for true and 0 for false!

	defcode "=",1,,EQU
	POPPSP	r0
	POPPSP	r1
	cmp	r0, r1
	moveq	r0, #1
	movne	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "<>",2,,NEQU
	POPPSP	r0
	POPPSP	r1
	cmp	r0, r1
	movne	r0, #1
	moveq	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "<",1,,LT
	POPPSP	r0
	POPPSP	r1
	cmp	r0, r1
	movlt	r0, #1
	movge	r0, #0
	PUSHPSP	r0
	NEXT

	defcode ">",1,,GT
	POPPSP	r0
	POPPSP	r1
	cmp	r0, r1
	movgt	r0, #1
	movle	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "<=",2,,LE
	POPPSP	r0
	POPPSP	r1
	cmp	r0, r1
	movle	r0, #1
	movge	r0, #0
	PUSHPSP	r0
	NEXT

	defcode ">=",2,,GE
	POPPSP	r0
	POPPSP	r1
	cmp	r0, r1
	movge	r0, #1
	movlt	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "0=",2,,ZEQU
	POPPSP	r0
	cmp	r0, #0
	moveq	r0, #1
	movne	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "0<>",3,,ZNEQU
	POPPSP	r0
	cmp	r0, #0
	movne	r0, #1
	moveq	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "0<",2,,ZLT
	POPPSP	r0
	cmp	r0, #0
	movlt	r0, #1
	movge	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "0>",2,,ZGT
	POPPSP	r0
	cmp	r0, #0
	movgt	r0, #1
	movle	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "0<=",3,,ZLE
	POPPSP	r0
	cmp	r0, #0
	movle	r0, #1
	movgt	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "0>=",3,,ZGE
	POPPSP	r0
	cmp	r0, #0
	movge	r0, #1
	movlt	r0, #0
	PUSHPSP	r0
	NEXT

	defcode "AND",3,,AND
	POPPSP	r0
	POPPSP	r1
	and	r0, r1, r0
	PUSHPSP	r0
	NEXT

	defcode "OR",2,,OR
	POPPSP	r0
	POPPSP	r1
	orr	r0, r1, r0
	PUSHPSP	r0
	NEXT

	defcode "XOR",3,,XOR
	POPPSP	r0
	POPPSP	r1
	eor	r0, r1, r0
	PUSHPSP	r0
	NEXT

	defcode "INVERT",6,,INVERT
	ldr	r0, [PSP]
	mvn	r0, r0
	str	r0, [PSP]
	NEXT


	defcode "EXIT",4,,EXIT
	POPRSP	NIP
	NEXT

	defcode "LIT",3,,LIT
	ldr	T0, [NIP], #4	@ grab and skip literal value
	PUSHPSP	T0		@ push it
	NEXT

	defcode "!",1,,STORE
	POPPSP	r0		@ address
	POPPSP	r1		@ value
	str	r1, [r0]	@ store
	NEXT

	defcode "@",1,,FETCH
	POPPSP	r0		@ address
	ldr	r1, [r0]	@ load
	PUSHPSP	r1
	NEXT

	defcode "+!",2,,ADDSTORE
	POPPSP	r0		@ address
	POPPSP	r1		@ amount to add
	ldr	r2, [r0]
	add	r2, r2, r1
	str	r2, [r0]
	NEXT

	defcode "-!",2,,SUBSTORE
	POPPSP	r0		@ address
	POPPSP	r1		@ amount to subtract
	ldr	r2, [r0]
	sub	r2, r2, r1
	str	r2, [r0]
	NEXT

	defcode "C!",2,,STOREBYTE
	POPPSP	r0		@ address
	POPPSP	r1		@ value
	strb	r1, [r0]	@ store
	NEXT

	defcode "C@",2,,FETCHBYTE
	POPPSP	r0		@ address
	ldrb	r1, [r0]	@ load and sign extend
	PUSHPSP	r1
	NEXT

	defcode "C@C!",4,,CCOPY
	ldr	r0, [PSP, #4]	@ source address
	ldr	r1, [PSP]	@ destination address
	ldrb	r2, [r0], #1	@ load and increment
	strb	r2, [r1], #1	@ store and increment
	str	r0, [PSP, #4]	@ update source
	str	r1, [PSP]	@ update destination
	NEXT

	defcode "CMOVE",5,,CMOVE
	POPPSP	r0		@ length
	POPPSP	r1		@ destination address
	POPPSP	r2		@ source address
1:	cmp	r0, #0
	ldrgtb	r3, [r2], #1	@ load, increment r2
	strgtb	r3, [r1], #1	@ store, increment r3
	subgt	r0, r0, #1	@ decrement counter
	bgt	1b		@ until length = 0
	NEXT

	.macro defvar name, namelen, flags=0, label, initial=0
	defcode \name,\namelen,\flags,\label
	ldr	r0, =var_\name	@ load address
	ldr	r0, [r0]	@ load value from address
	PUSHPSP	r0		@ push value
	NEXT
	.data
	.align 2
var_\name :
	.int \initial
	.endm

	defvar "STATE",5,,STATE
	defvar "HERE",4,,HERE
	defvar "LATEST",6,,LATEST,name_SYSCALL0 // SYSCALL0 must be last in built-in dictionary
	defvar "S0",2,,SZ
	defvar "BASE",4,,BASE,10

#include <asm/unistd.h>

	.macro defconst name, namelen, flags=0, label, value
	defcode \name,\namelen,\flags,\label
	ldr	r0, =\value
	PUSHPSP	r0
	NEXT
	.endm

	defconst "VERSION",7,,VERSION,JONES_VERSION
	defconst "R0",2,,RZ,return_stack_top
	defconst "DOCOL",5,,__DOCOL,DOCOL
	defconst "F_IMMED",7,,__F_IMMED,F_IMMED
	defconst "F_HIDDEN",8,,__F_HIDDEN,F_HIDDEN
	defconst "F_LENMASK",9,,__F_LENMASK,F_LENMASK

	defconst "SYS_EXIT",8,,SYS_EXIT,__NR_exit
	defconst "SYS_OPEN",8,,SYS_OPEN,__NR_open
	defconst "SYS_CLOSE",9,,SYS_CLOSE,__NR_close
	defconst "SYS_READ",8,,SYS_READ,__NR_read
	defconst "SYS_WRITE",9,,SYS_WRITE,__NR_write
	defconst "SYS_CREAT",9,,SYS_CREAT,__NR_creat
	defconst "SYS_BRK",7,,SYS_BRK,__NR_brk

	defconst "O_RDONLY",8,,__O_RDONLY,0
	defconst "O_WRONLY",8,,__O_WRONLY,1
	defconst "O_RDWR",6,,__O_RDWR,2
	defconst "O_CREAT",7,,__O_CREAT,0100
	defconst "O_EXCL",6,,__O_EXCL,0200
	defconst "O_TRUNC",7,,__O_TRUNC,01000
	defconst "O_APPEND",8,,__O_APPEND,02000
	defconst "O_NONBLOCK",10,,__O_NONBLOCK,04000

	defcode ">R",2,,TOR
	POPPSP	r0
	PUSHRSP	r0
	NEXT

	defcode "R>",2,,FROMR
	POPRSP	r0
	PUSHPSP	r0
	NEXT

	defcode "RSP@",4,,RSPFETCH
	PUSHPSP	RSP
	NEXT

	defcode "RSP!",4,,RSPSTORE
	POPPSP	RSP
	NEXT

	defcode "RDROP",5,,RDROP
	add	RSP, RSP, #4
	NEXT

	defcode "DSP@",4,,DSPFETCH
	mov	r0, PSP
	PUSHPSP	r0
	NEXT

	defcode "DSP!",4,,DSPSTORE
	POPPSP	r0
	mov	PSP, r0
	NEXT


	defcode "KEY",3,,KEY
	bl	_KEY
	PUSHPSP	T0
	NEXT
_KEY:
	@ KEY () (char: T0)
	stmfd	sp!, {S2,S3}
3:
	ldr	S3, =currkey		@ address of currkey
	ldr	T3, [S3]		@ value of currkey (address in buffer)
	ldr	S2, =bufftop		@ address of bufftop
	ldr	T2, [S2]		@ value of bufftop (address in buffer)
	cmp	T3, T2			@ currkey >= bufftop?
	bge	1f			@ yes, need more input
	ldrb	T0, [T3], #1		@ load character and increment currkey
	str	T3, [S3]		@ update currkey

	ldmfd	sp!, {S2,S3}
	bx	lr			@ return
1:
	mov	T0, #stdin
	ldr	T1, =buffer
	mov	T2, #BUFFER_SIZE
	svc	__NR_read
	cmp	T0, #0			@ <= 0?
	ble	2f			@ yes, fatal error
	ldr	T1, =buffer
	str	T1, [S3]		@ reset currkey (to beginning of buffer)
	add	T1, T1, T0
	str	T1, [S2]		@ update bufftop (with length we read)
	b	3b			@ try fast path again
2:
	svc	__NR_exit		@ exit (with error code from NR_read)

	.data
	.align 2
currkey:
	.int buffer		// Current place in input buffer (next character to read).
bufftop:
	.int buffer		// Last valid data in input buffer + 1.


	defcode "EMIT",4,,EMIT
	POPPSP	T0
	bl	_EMIT
	NEXT
_EMIT:
	@ EMIT (char: T0) ()
	mov	T2, #1			@ length
	ldr	T1, =emit_scratch	@ buffer
	strb	T0, [T1]		@ store char in buffer
	mov	T0, #stdout
	svc	__NR_write
	bx	lr

	.data
emit_scratch:
	.space 1


	defcode "WORD",4,,WORD
	bl _WORD
	PUSHPSP	T0			@ address
	PUSHPSP	T1			@ length
	NEXT
_WORD:
	@ WORD () (address: T0, length: T1)
	stmfd	sp!, {S0,lr}
1:
	bl	_KEY
	cmp	T0, #'\\'		@ comment?
	beq	3f			@ skip comment
	cmp	T0, #' '		@ space?
	beq	1b			@ keep looking

	ldr	S0, =word_buffer	@ address
2:
	strb	T0, [S0], #1		@ store character, increment pointer
	bl	_KEY
	cmp	T0, #' '		@ space?
	bne	2b			@ keep looking

	ldr	T0, =word_buffer	@ address
	sub	T1, S0, T0		@ length

	ldmfd	sp!, {S0,lr}
	bx	lr
3:
	bl	_KEY
	cmp	T0, #'\n'		@ eol?
	bne	3b			@ keep looking
	b	1b

	.data
word_buffer:
	.space 32



	defcode "NUMBER",6,,NUMBER
	POPPSP	T1		@ length of string
	POPPSP	T0		@ address of string
	bl	_NUMBER
	PUSHPSP	T0		@ number
	PUSHPSP	T1		@ # unparsed
	NEXT

_NUMBER:
	@ NUMBER(address: T0, length: T1) (number: T0, unparsed: T1)
	stmfd	sp!, {S0,S1,S2,S3}

	mov	T2, T0		@ address
	mov	T3, T1		@ length
	mov	T0, #0		@ number
	mov	T1, #0		@ unparsed
	cmp	T3, #0		@ length <= 0?
	ble	5f		@ really an error, but "fake" a 0 instead

	ldr	S0, =var_BASE
	ldr	S0, [S0]	@ get BASE
	ldrb	S1, [T2], #1	@ get character and increment address
	mov	S3, #0		@ set negative flag false
	cmp	S1, #'-'	@ leading '-'?
	bne	2f		@ nope, try to parse as digit

	mov	S3, #1		@ set negative flag true
	subs	T3, T3, #1	@ decrement length
	bne	1f		@ >0 so keep going

	mov	T1, #1		@ just a sign, no digits, signal an error
	b	5f		@ error!
1:
	mul	S2, T0, S0	@ number = number * BASE
	mov	T0, S2		@ (need to use another register for mul to avoid warning)
	ldrb	S1, [T2], #1	@ get character and increment address
2:
	subs	S1, S1, #'0'	@ try lower digit bound
	blt	4f		@ nope, < '0' so we're done
	cmp	S1, #10		@ try upper digit bound
	blt	3f		@ yes, we got one!
	subs	S1, S1, #17	@ try lower char bound (17 is 'A'-'0')
	blt	4f		@ nope, < 'A' so we're done
	add	S1, S1, #10	@ adjust for first 10 digit values before 'A'
3:
	cmp	S1, S0		@ >= BASE?
	bge	4f		@ yep, we're done

	@ finally, add new digit to number and loop
	add	T0, S1
	subs	T3, T3, #1
	bne	1b
4:
	cmp	S3, #1		@ check negative flag
	rsbeq	T0, T0, #0	@ yes, negate (r0 = 0 - r0)
5:
	ldmfd	sp!, {S0,S1,S2,S3}
	bx	lr





	defcode "FIND",4,,FIND
	POPPSP	T1			@ length of string
	POPPSP	T0			@ address of string
	bl	_FIND
	PUSHPSP	T0			@ address of dictionary entry
	NEXT

_FIND:
	@ FIND (address: T0, length: T1) (address: T0)
	stmfd	sp!, {S0,S1,S2,S3}

	mov	T2, T1			@ length
	mov	T1, T0			@ address
	ldr	T0, =var_LATEST
	ldr	T0, [T0]		@ current dictionary pointer
1:
	cmp	T0, #0			@ NULL?
	beq	4f			@ end of list!

	ldrb	T3, [T0, #4]		@ flags+length field
	and	T3, T3, #(F_HIDDEN|F_LENMASK)
	cmp	T2, T2			@ length the same?
	bne	2f			@ nope, skip this entry

	@ T2 = T3, but T3 can be destroyed in the loop

	mov	S0, T1			@ current char in string A
	mov	S1, T0
	add	S1, S1, #5		@ current char in string B
10:
	ldrb 	S2, [S0], #1		@ char A, increment
	ldrb	S3, [S1], #1		@ char B, increment
	cmp	S2, S3			@ A = B?
	bne	2f			@ nope
	subs	T3, T3, #1		@ decrement
	bne	10b			@ > 0, keep going

	@ strings are equal, T0 is the correct entry pointer
	b	4f
2:
	ldr	T0, [T0]		@ previous dictionary pointer
	b	1b			@ try again
4:
	ldmfd   sp!, {S0,S1,S2,S3}
	bx	lr





	defcode ">CFA",4,,TCFA
	POPPSP	T0
	bl	_TCFA
	PUSHPSP	T0
	NEXT
_TCFA:
	@ TCFA (address: T0) (address: T0)
	add	T0, T0, #4		@ skip link pointer
	ldrb	T1, [T0]		@ load flags+len
	add	T0, T0, #1		@ skip flags+len bytes
	and	T1, T1, #F_LENMASK	@ mask out flags
	add	T0, T0, T1		@ skip name
	add	T0, T0, #3		@ align to 4-byte boundary
	and	T0, T0, #~3
	bx	lr



	defword ">DFA",4,,TDFA
	.int TCFA		// >CFA		(get code field address)
	.int INCR4		// 4+		(add 4 to it to get to next word)
	.int EXIT		// EXIT		(return from FORTH word)


	defcode "CREATE",6,,CREATE
	@ TODO: shouldn't this ensure length > 0?
	POPPSP	r1		@ length
	POPPSP	r0		@ address

	ldr	r2, =var_HERE	@ address of HERE
	ldr	r3, [r2]	@ value of HERE, address of new header
	ldr	r4, =var_LATEST	@ address of LATEST
	ldr	r5, [r4]	@ value of LATEST, link pointer
	str	r3, [r4]	@ update LATEST to refer to new header
	str	r5, [r3], #4	@ store link pointer in header, increment header

	strb	r1, [r3], #1	@ store length/flags byte, increment header

	@ we don't need the length in r1 anymore now, so we can destroy it
	@ r4 and r5 are also free again
1:
	cmp	r1, #0
	ldrgtb	r4, [r1], #1	@ get character, increment
	strgtb	r4, [r3], #1	@ put character, increment header
	subs	r1, r1, #1	@ decrement length
	bgt	1b

	add	r3, r3, #3	@ align
	and	r3, r3, #~3

	str	r3, [r2]	@ update HERE
	NEXT


	defcode ",",1,,COMMA
	POPPSP	T0
	bl	_COMMA
	NEXT
_COMMA:
	@ COMMA (codeword: T0) ()
	ldr	r1, =var_HERE	@ address of HERE
	ldr	r2, [r1]	@ value of HERE
	str	r0, [r2], #4	@ store code word, increment
	str	r2, [r1]	@ update HERE
	bx	lr


	defcode "[",1,F_IMMED,LBRAC
	ldr	r0, =var_STATE	@ address of STATE
	mov	r1, #0
	str	r1, [r0]	@ update STATE
	NEXT

	defcode "]",1,,RBRAC
	ldr	r0, =var_STATE	@ address of STATE
	mov	r1, #1
	str	r1, [r0]	@ update STATE
	NEXT


	defword ":",1,,COLON
	.int WORD		// Get the name of the new word
	.int CREATE		// CREATE the dictionary entry / header
	.int LIT, DOCOL, COMMA	// Append DOCOL  (the codeword).
	.int LATEST, FETCH, HIDDEN // Make the word hidden (see below for definition).
	.int RBRAC		// Go into compile mode.
	.int EXIT		// Return from the function.

	defword ";",1,F_IMMED,SEMICOLON
	.int LIT, EXIT, COMMA	// Append EXIT (so the word will return).
	.int LATEST, FETCH, HIDDEN // Toggle hidden flag -- unhide the word (see below for definition).
	.int LBRAC		// Go back to IMMEDIATE mode.
	.int EXIT		// Return from the function.


	defcode "IMMEDIATE",9,F_IMMED,IMMEDIATE
	ldr	r0, =var_LATEST		@ address of LATEST
	ldr	r0, [r0]		@ value of LATEST
	ldrb	r1, [r0, #4]		@ get length/flag byte
	eor	r1, r1, #F_IMMED	@ toggle IMMED bit
	strb	r1, [r0, #4]		@ update length/flag byte
	NEXT

	defcode "HIDDEN",6,,HIDDEN
	POPPSP	r0			@ dictionary entry
	ldrb	r1, [r0, #4]		@ get length/flag byte
	eor	r1, r1, #F_HIDDEN	@ toggle HIDDEN bit
	strb	r1, [r0, #4]		@ update length/flag byte
	NEXT

	defword "HIDE",4,,HIDE
	.int WORD		// Get the word (after HIDE).
	.int FIND		// Look up in the dictionary.
	.int HIDDEN		// Set F_HIDDEN flag.
	.int EXIT		// Return.


	defcode "'",1,,TICK
	ldr	r0, [NIP], #4	@ load address of next word from NIP, increment NIP to skip it
	PUSHPSP	r0
	NEXT


	defcode "BRANCH",6,,BRANCH
	ldr	r0, [NIP]	@ offset to add
	add	NIP, NIP, r0	@ add it!
	NEXT

	defcode "0BRANCH",7,,ZBRANCH
	POPPSP	r0
	cmp	r0, #0		@ top of stack zero?
	beq	code_BRANCH	@ yes, do the branch
	add	NIP, NIP, #4	@ no, skip the offset
	NEXT


	defcode "LITSTRING",9,,LITSTRING
	ldr	r0, [NIP], #4	@ get length of string, increment
	PUSHPSP	NIP		@ push address of string
	PUSHPSP	r0		@ push length of string
	add	NIP, NIP, r0	@ skip past the string
	add	NIP, NIP, #3	@ align
	and	NIP, NIP, #~3
	NEXT

	defcode "TELL",4,,TELL
	mov	T0, #stdout
	POPPSP	T2		@ length
	POPPSP	T1		@ address
	svc	__NR_write
	NEXT


	defword "QUIT",4,,QUIT
	.int RZ,RSPSTORE	// R0 RSP!, clear the return stack
	.int INTERPRET		// interpret the next word
	.int BRANCH,-8		// and loop (indefinitely)





	defcode "INTERPRET",9,,INTERPRET
	mov	S3, #0			@ reset interpret_is_lit flag

	bl	_WORD			@ returns T0 = address, T1 = length
	mov	S0, T0			@ address
	mov	S1, T1			@ length
	bl	_FIND			@ returns T0 = dictionary entry
	cmp	T0, #0			@ = NULL?
	beq	1f			@ not found!

	@ found in dictionary, check if it's immediate
	ldrb	S2, [T0, #4]		@ load length/flags byte
	bl	_TCFA			@ returns T0 = codeword pointer 
	tst	S2, #F_IMMED		@ test immediate flag
	bne	4f			@ jump straight to execute!
	b	2f			@ jump to compile/execute?

1:	@ not in dictionary, check if it's a number
	add	S3, S3, #1		@ set interpret_is_lit flag
	mov	T0, S0			@ address
	mov	T1, S1			@ length
	bl	_NUMBER			@ returns T0 = number, T1 = unparsed
	cmp	T1, #0			@ unparsed > 0?
	bne	6f			@ error!

	mov	S2, T0			@ number
	ldr	T0, =LIT		@ codeword is LIT

2:	@ compiling or executing?
	ldr	T2, =var_STATE		@ address of STATE
	ldr	T2, [T2]		@ value of STATE
	cmp	T2, #0			@ STATE == 0?
	beq	4f			@ jump straight to execute!

	@ compiling, append word to current dictionary definition
	bl	_COMMA			@ expects codeword in T0
	cmp	S3, #0			@ interpret_is_lit == 0?
	beq	3f			@ yep, so we're done

	mov	T0, S2			@ number
	bl	_COMMA			@ expects codeword in T0
3:
	NEXT


4:	@ executing, so run the word
	cmp	S3, #0			@ interpret_is_lit != 0?
	bne	5f			@ yep, so let's push

	@ not a literal, execute! never returns, but eventually NEXT will get
	@ called and reenter the loop in QUIT
	bx	T0

5:	@ execute literal, which means push it
	PUSHPSP	S2
	NEXT

6:
	@ parse error, print context from input buffer
	mov	T0, #stderr
	ldr	T1, =errmsg		@ address
	mov	T2, #errmsgend-errmsg	@ length
	svc	__NR_write

	mov	T0, #stderr
	ldr	T1, =currkey		@ address of currkey
	ldr	T1, [T1]		@ value of currkey, pointer in buffer
	ldr	T2, =buffer		@ address of buffer
	sub	T2, T1, T2		@ length = currkey - buffer
	cmp	T2, #40			@ > 40?
	movgt	T2, #40			@ cap at 40
	svc	__NR_write

	mov	T0, #stderr
	ldr	T1, =errmsgnl		@ address
	mov	T2, #1			@ length
	svc	__NR_write
	NEXT

	.section .rodata
errmsg: .ascii "PARSE ERROR: "
errmsgend:
errmsgnl: .ascii "\n"


	defcode "CHAR",4,,CHAR
	bl	_WORD			@ returns T0 = address, T1 = length
	ldrb	T0, [T0]		@ get first character
	PUSHPSP	T0			@ push it
	NEXT


	defcode "EXECUTE",7,,EXECUTE
	POPPSP	T0			@ grab execution token, whatever that is?
	bx	T0			@ jump to it (execution token's NEXT will continue)

@ The SYSCALL? words are somewhat of a pain for OABI since we don't
@ pass the syscall number in a register. So instead we need a table
@ of svc instructions out of which we select one. This requires the
@ syscall numbers to be "adjusted" appropriately. For EABI we could
@ do better of course...

	.text
oabi_syscall_table:
	.space	8		@ 0 __NR_restart_syscall
	svc	__NR_exit	@ 1
	bx	lr
	.space	8		@ 2 __NR_fork
	svc	__NR_read	@ 3
	bx	lr
	svc	__NR_write	@ 4
	bx	lr
	svc	__NR_open	@ 5
	bx	lr
	svc	__NR_close	@ 6
	bx	lr
	.space	8		@ 7 __NR_waitpid (deprecated)
	svc	__NR_creat	@ 8
	bx	lr
	.space	8		@ 9
	.space	8		@ 10
	.space	8		@ 11
	.space	8		@ 12
	.space	8		@ 13
	.space	8		@ 14
	.space	8		@ 15
	.space	8		@ 16
	.space	8		@ 17
	.space	8		@ 18
	.space	8		@ 19
	.space	8		@ 20
	.space	8		@ 21
	.space	8		@ 22
	.space	8		@ 23
	.space	8		@ 24
	.space	8		@ 25
	.space	8		@ 26
	.space	8		@ 27
	.space	8		@ 28
	.space	8		@ 29
	.space	8		@ 30
	.space	8		@ 31
	.space	8		@ 32
	.space	8		@ 33
	.space	8		@ 34
	.space	8		@ 35
	.space	8		@ 36
	.space	8		@ 37
	.space	8		@ 38
	.space	8		@ 39
	.space	8		@ 40
	.space	8		@ 41
	.space	8		@ 42
	.space	8		@ 43
	.space	8		@ 44
	svc	__NR_brk	@ 45
	bx	lr
	.space	8		@ 46
	.space	8		@ 47
	.space	8		@ 48
	.space	8		@ 49
	.space	8		@ 50



	defcode "SYSCALL3",8,,SYSCALL3
	POPPSP	r7		@ syscall number
	@ begin OABI adjustments
	sub	r7, r7, #__NR_OABI_SYSCALL_BASE
	ldr	r0, =oabi_syscall_table
	add	r7, r0, r7, LSL #3
	@ end OABI adjustments
	POPPSP	r0		@ first parameter
	POPPSP	r1		@ second parameter
	POPPSP	r2		@ third parameter
	@ OABI system call
	blx	r7
	PUSHPSP	r0		@ result
	NEXT

	defcode "SYSCALL2",8,,SYSCALL2
	POPPSP	r7		@ syscall number
	@ begin OABI adjustments
	sub	r7, r7, #__NR_OABI_SYSCALL_BASE
	ldr	r0, =oabi_syscall_table
	add	r7, r0, r7, LSL #3
	@ end OABI adjustments
	POPPSP	r0		@ first parameter
	POPPSP	r1		@ second parameter
	@ OABI system call
	blx	r7
	PUSHPSP	r0		@ result
	NEXT

	defcode "SYSCALL1",8,,SYSCALL1
	POPPSP	r7		@ syscall number
	@ begin OABI adjustments
	sub	r7, r7, #__NR_OABI_SYSCALL_BASE
	ldr	r0, =oabi_syscall_table
	add	r7, r0, r7, LSL #3
	@ end OABI adjustments
	POPPSP	r0		@ first parameter
	@ OABI system call
	blx	r7
	PUSHPSP	r0		@ result
	NEXT

	defcode "SYSCALL0",8,,SYSCALL0
	POPPSP	r7		@ syscall number
	@ begin OABI adjustments
	sub	r7, r7, #__NR_OABI_SYSCALL_BASE
	ldr	r0, =oabi_syscall_table
	add	r7, r0, r7, LSL #3
	@ end OABI adjustments
	@ OABI system call
	blx	r7
	PUSHPSP	r0		@ result
	NEXT

	.text
	.set INITIAL_DATA_SEGMENT_SIZE,65536
set_up_data_segment:
	mov	r0, #0
	svc	__NR_brk
	ldr	r1, =var_HERE
	str	r0, [r1]
	add	r0, r0, #INITIAL_DATA_SEGMENT_SIZE
	svc	__NR_brk
	bx	lr

	.set RETURN_STACK_SIZE,8192
	.set BUFFER_SIZE,4096

	.text
debug_ping:
	stmfd	sp!, {r0-r12}
	mov	r0, #stderr
	ldr	r1, =debugmsg		@ address
	mov	r2, #debugend-debugmsg	@ length
	svc	__NR_write
	ldmfd	sp!, {r0-r12}
	bx	lr
	.section .rodata
debugmsg:
	.ascii "\nPING!\n"
debugend:

	.bss
	.align 12
return_stack:
	.space RETURN_STACK_SIZE
return_stack_top:

	.align 12
buffer:
	.space BUFFER_SIZE
