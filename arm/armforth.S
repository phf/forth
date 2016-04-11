@ armforth.S - Porting Richard Jones' FORTH to ARM
@
@ Copyright (c) 2010, 2016 by Peter H. Froehlich <phf@acm.org>
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
@	r14		lr		link register/scratch
@	r13		sp		stack pointer
@	r12		ip		linker scratch/new sb?
@	r11		v8/fp		variable/frame pointer
@	r10		v7/sl		variable/stack limit
@	r9		v6/sb/tr	variable/static base/platform special
@	r8		v5		variable
@	r7		v4		variable/EABI special (syscall)
@	r6		v3		variable
@	r5		v2		variable
@	r4		v1		variable
@	r3		a4		argument/scratch/result
@	r2		a3		argument/scratch/result
@	r1		a2		argument/scratch/result
@	r0		a1		argument/scratch/result
@
@ Registers v1-v8 and sp are callee-saved, except of
@ course if they are "special". Registers a1-a4 and lr
@ seem to be caller-saved by implication.
@
@ Assembly
@ ========
@
@ .align for x86 is bytes, for ARM it's powers of two
@
@ SUB a, b, c <=> a = b - c
@ RSB a, b, c <=> a = c - b
@
@ CMP a, b <=> flags for a - b
@
@ LDR a, [b, #c]  <=> a = M[b + #c]
@ LDR a, [b, #c]! <=> a = M[b + #c], b = b + #c
@ LDR a, [b], #c  <=> a = M[b], b = b + #c
@
@ FORTH
@ =====
@       pre      post
@       vvvvv    vvv
@ WORD (a b c -- d e)
@           ^      ^
@          top    top
@
@	WORD expects c on top, then b, then a
@	WORD leaves e on top, then d

#include <asm/unistd.h>

PSP	.req	r13	@ parameter stack pointer (also ARM sp)
RSP	.req	r11	@ return stack pointer
NIP	.req	r10	@ next instruction pointer
T0	.req	r0	@ caller-saved (our FORTH convention)
T1	.req	r1
T2	.req	r2
T3	.req	r3
U0	.req	r4	@ callee-saved (our FORTH convention)
U1	.req	r5	@ (these were S0-S3 for MIPS-appeal originally)
U2	.req	r6
U3	.req	r8

@ Note that we avoided r7, r9, and r12 because they are "special"
@ in various ways. In the following r7 is used for system calls
@ for example.

	.set	stdin,0
	.set	stdout,1
	.set	stderr,2

@ Execute the NEXT codeword. Each word in the dictionary starts with
@ a so-called codeword: Where should we jump to run this word? If we
@ are dealing with a word written in assembly, we just jump to that,
@ the assembly code. But if we are dealing with a word written in FORTH,
@ we jump to DOCOL, code that knows how to interpret a FORTH word. (You
@ should really look at Richard's pictures for this.) Note that DOCOL
@ needs the WORD in T0, that's why we use two registers here.

	.macro NEXT
	ldr	T0, [NIP], #4	@ load WORD from NIP, increment NIP
	ldr	T1, [T0]	@ load CODEWORD (offset 0 of WORD)
	bx	T1		@ jump to CODEWORD
	.endm

@ We use two stacks, one for return addresses and one for parameters.
@ The parameter stack coincides with the regular ARM stack, so we can
@ use PUSH and POP instructions. In line with ARM conventions, we use
@ full descending stacks (decrement, then store; load, then increment).

	.macro PUSHRSP reg
	str	\reg, [RSP, #-4]!	@ store at RSP-4, decrement RSP
	.endm

	.macro POPRSP reg
	ldr	\reg, [RSP], #4		@ load from RSP, increment RSP
	.endm

	.macro PUSHPSP reg
	push	{\reg}
	.endm

	.macro POPPSP reg
@	push	{T0}
@	ldr	T0, =var_S0
@	ldr	T0, [T0]
@	cmp	T0, PSP
@	ble	fatal_stack
@	pop	{T0}
	pop	{\reg}
	.endm

@	.text
@	.align	2
@fatal_stack:
@	mov	T0, #stderr
@	ldr	T1, =stackmsg			@ address
@	mov	T2, #stackmsgend-stackmsg	@ length
@	mov	r7, #__NR_write
@	svc	#0
@	mov	T0, #-1
@	mov	r7, #__NR_exit
@	svc	#0

@	.section .rodata
@stackmsg:
@	.ascii "STACK UNDERFLOW\n"
@stackmsgend:

@ We get here only from NEXT, so T0 is guaranteed to be the WORD we
@ are supposed to run. We need to skip the codeword at offset 0
@ though, that points to DOCOL after all!

	.text
	.align 2
DOCOL:
	PUSHRSP	NIP		@ push NIP on return stack
	add	NIP, T0, #4	@ skip codeword, make NIP the first dataword
	NEXT

@ Here comes the entry point. Note that var_S0 is a FORTH variable
@ that's supposed to hold the "start" of the parameter stack. It's
@ used in jonesforth.f to implement some fancy stack stuff, but it's
@ not used here.

	.text
	.align 2
	.global _start
_start:
	@ store initial PSP in var_S0 FORTH variable
	ldr	T0, =var_S0
	str	PSP, [T0]
	@ initialize the return stack
	ldr	RSP, =return_stack_top
	@ initialize data segment (sets var_HERE FORTH variable)
	bl	set_up_data_segment
	@ initialize the interpreter with a "fake" cold_start WORD
	ldr	NIP, =cold_start
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
	.pool
	.global code_\label
code_\label :
	push	{r0-r12,lr}
	ldr	r0, =name_\label+5	@ address
	mov	r1, #\namelen		@ length
	bl	debug_pong
	pop	{r0-r12,lr}
	@ assembler code follows
	.endm

	@ DROP (a -- )
	defcode "DROP",4,,DROP
	add PSP, PSP, #4	@ POPPSP would load uselessly
	NEXT

	@ SWAP (a b -- b a)
	defcode "SWAP",4,,SWAP	@ avoid POP/PUSH macros
	ldr	T0, [PSP]	@ load from PSP
	ldr	T1, [PSP, #4]	@ load from PSP+4
	str	T0, [PSP, #4]	@ store to PSP+4
	str	T1, [PSP]	@ store to PSP
	NEXT

	@ DUP (a -- a a)
	defcode "DUP",3,,DUP
	ldr	T0, [PSP]	@ POPPSP would require two PUSHPSPs
	PUSHPSP	T0
	NEXT

	@ OVER (a b -- a b a)
	defcode "OVER",4,,OVER
	ldr	T0, [PSP, #4]
	PUSHPSP	T0
	NEXT

	@ ROT (a b c -- b c a)
	defcode "ROT",3,,ROT
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	POPPSP	T2
	PUSHPSP	T1
	PUSHPSP	T0
	PUSHPSP	T2
	NEXT

	@ -ROT (a b c -- c a b)
	defcode "-ROT",4,,NROT
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	POPPSP	T2
	PUSHPSP	T0
	PUSHPSP	T2
	PUSHPSP	T1
	NEXT

@ for debugging, switch PONG messages ON/OFF
	defcode "DONG",4,,DONG
	ldr	T0, =var_PONG
	ldr	T1, [T0]
	mvn	T1, T1
	str	T1, [T0]
	NEXT

	@ 2DROP (a b -- )
	defcode "2DROP",5,,TWODROP
	add	PSP, PSP, #8	@ POPPSP would load from memory
	NEXT

	@ 2DUP (a b -- a b a b)
	defcode "2DUP",4,,TWODUP
	ldr	T0, [PSP]	@ POPPSP would require two PUSHPSPs
	ldr	T1, [PSP, #4]	@ same
	PUSHPSP	T1
	PUSHPSP	T0
	NEXT

	@ 2SWAP (a b c d -- c d a b)
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

	@ ?DUP (0 -- 0)
	@ ?DUP (a -- a a)
	defcode "?DUP",4,,QDUP
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	cmp	T0, #0		@ != 0?
	pushne	{T0}		@ PUSHPSP is not conditional
	NEXT

	@ 1+ (a -- a+1)
	defcode "1+",2,,INCR
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	add	T0, T0, #1
	str	T0, [PSP]
	NEXT

	@ 1- (a -- a-1)
	defcode "1-",2,,DECR
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	sub	T0, T0, #1
	str	T0, [PSP]
	NEXT

	@ 4+ (a -- a+4)
	defcode "4+",2,,INCR4
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	add	T0, T0, #4
	str	T0, [PSP]
	NEXT

	@ 4- (a -- a-4)
	defcode "4-",2,,DECR4
	ldr	T0, [PSP]	@ POPPSP would require PUSHPSP
	sub	T0, T0, #4
	str	T0, [PSP]
	NEXT

	@ + (a b -- a+b)
	defcode "+",1,,ADD
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	add	T0, T1, T0
	PUSHPSP	T0
	NEXT

	@ - (a b -- a-b)
	defcode "-",1,,SUB
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	sub	T0, T1, T0
	PUSHPSP	T0
	NEXT

	@ * (a b -- a*b)
	defcode "*",1,,MUL
	POPPSP	T0		@ TODO: avoid unecessary PSP updates
	POPPSP	T1
	mul	T0, T1, T0
	PUSHPSP	T0
	NEXT

	@ /MOD (a b -- a%b a/b)
	defcode "/MOD",4,,DIVMOD
	POPPSP	T1		@ denominator
	POPPSP	T0		@ numerator
	bl	_DIVMOD
	PUSHPSP	T3		@ remainder
	PUSHPSP	T2		@ quotient
	NEXT
_DIVMOD:
	push	{lr}
	cmp	T1, #0
	beq	1f
	blt	2f
	cmp	T0, #0
	blt	2f
	bl	unsigned_longdiv
	pop	{lr}
	bx	lr
1:
	@ division by 0 error
	mov	T0, #stderr
	ldr	T1, =divmsg		@ address
	mov	T2, #divmsgend-divmsg	@ length
	mov	r7, #__NR_write
	svc	#0
	mov	T0, #-1
	mov	r7, #__NR_exit
	svc	#0
2:
	@ negative division error
	mov	T0, #stderr
	ldr	T1, =posmsg		@ address
	mov	T2, #posmsgend-posmsg	@ length
	mov	r7, #__NR_write
	svc	#0
	mov	T0, #-1
	mov	r7, #__NR_exit
	svc	#0

	.section .rodata
divmsg: .ascii "DIVISION BY 0!\n"
divmsgend:
posmsg: .ascii "NEGATIVE DIVISION!\n"
posmsgend:

@ All predicates use 1 for true and 0 for false, unlike the FORTH
@ standard. That's just as well.

	@ = (a b -- a=b)
	defcode "=",1,,EQU
	POPPSP	T0
	POPPSP	T1
	cmp	T1, T0
	moveq	T0, #1
	movne	T0, #0
	PUSHPSP	T0
	NEXT

	@ <> (a b -- a<>b)
	defcode "<>",2,,NEQU
	POPPSP	T0
	POPPSP	T1
	cmp	T1, T0
	movne	T0, #1
	moveq	T0, #0
	PUSHPSP	T0
	NEXT

	@ < (a b -- a<b)
	defcode "<",1,,LT
	POPPSP	T0
	POPPSP	T1
	cmp	T1, T0
	movlt	T0, #1
	movge	T0, #0
	PUSHPSP	T0
	NEXT

	@ > (a b -- a>b)
	defcode ">",1,,GT
	POPPSP	T0
	POPPSP	T1
	cmp	T1, T0
	movgt	T0, #1
	movle	T0, #0
	PUSHPSP	T0
	NEXT

	@ <= (a b -- a<=b)
	defcode "<=",2,,LE
	POPPSP	T0
	POPPSP	T1
	cmp	T1, T0
	movle	T0, #1
	movgt	T0, #0
	PUSHPSP	T0
	NEXT

	@ >= (a b -- a>=b)
	defcode ">=",2,,GE
	POPPSP	T0
	POPPSP	T1
	cmp	T1, T0
	movge	T0, #1
	movlt	T0, #0
	PUSHPSP	T0
	NEXT

@ TODO: register names inconsistent from here on out

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
	ldr	T0, [NIP], #4	@ load WORD from NIP, increment NIP
				@ which grabbed and skipped the literal
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
	@ used to ldr r0, [r0] here but we should only push
	@ the ADDRESS for a variable...
	PUSHPSP	r0		@ push address
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
@ for debugging
	defvar	"PONG",4,,PONG


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
	push	{U2,U3}
3:
	ldr	U3, =currkey		@ address of currkey
	ldr	T3, [U3]		@ value of currkey (address in buffer)
	ldr	U2, =bufftop		@ address of bufftop
	ldr	T2, [U2]		@ value of bufftop (address in buffer)
	cmp	T3, T2			@ currkey >= bufftop?
	bge	1f			@ yes, need more input
	ldrb	T0, [T3], #1		@ load character and increment currkey
	str	T3, [U3]		@ update currkey

	pop	{U2,U3}
	bx	lr			@ return
1:
	mov	r7, #__NR_read
	mov	T0, #stdin
	ldr	T1, =buffer
	mov	T2, #BUFFER_SIZE
	svc	#0
	cmp	T0, #0			@ <= 0?
	ble	2f			@ yes, fatal error
	ldr	T1, =buffer
	str	T1, [U3]		@ reset currkey (to beginning of buffer)
	add	T1, T1, T0
	str	T1, [U2]		@ update bufftop (with length we read)
	b	3b			@ try fast path again
2:
	mov	r7, #__NR_exit
	svc	#0			@ exit (with error code from NR_read)

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
	mov	r7, #__NR_write
	svc	#0
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
	push	{U0,lr}
1:
	bl	_KEY
	cmp	T0, #'\\'		@ == \?
	beq	3f			@ skip comment
	cmp	T0, #' '		@ <= ' '?
	ble	1b			@ keep looking

	ldr	U0, =word_buffer	@ address
2:
	strb	T0, [U0], #1		@ store character, increment pointer
	bl	_KEY
	cmp	T0, #' '		@ > ' '?
	bgt	2b			@ keep looking

	ldr	T0, =word_buffer	@ address
	sub	T1, U0, T0		@ length

	pop	{U0,lr}
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
	push	{U0,U1,U2,U3,lr}

	mov	T2, T0		@ address
	mov	T0, #0		@ number
	cmp	T1, #0		@ length <= 0?
	ble	5f		@ really an error, but returns 0 anyway

	ldr	U0, =var_BASE
	ldr	U0, [U0]	@ get BASE
	ldrb	U1, [T2], #1	@ get character and increment address
	mov	U3, #0		@ set negative flag false
	cmp	U1, #'-'	@ leading '-'?
	bne	2f		@ nope, try to parse as digit

	mov	U3, #1		@ set negative flag true
	subs	T1, T1, #1	@ decrement length
	bpl	1f		@ >0 so keep going

	mov	T1, #1		@ just a sign, no digits, signal an error
	b	5f		@ error!
1:
	mul	U2, T0, U0	@ number = number * BASE
	mov	T0, U2		@ (need to use another register for mul to avoid warning)
	ldrb	U1, [T2], #1	@ get character and increment address
2:
	subs	U1, U1, #'0'	@ try lower digit bound
	bmi	4f		@ nope, < '0' so we're done
	cmp	U1, #10		@ try upper digit bound
	blt	3f		@ yes, we got one!
	subs	U1, U1, #17	@ try lower char bound (17 is 'A'-'0')
	bmi	4f		@ nope, < 'A' so we're done
	add	U1, U1, #10	@ adjust for first 10 digit values before 'A'
3:
	cmp	U1, U0		@ >= BASE?
	bge	4f		@ yep, we're done

	@ finally, add new digit to number and loop
	add	T0, U1
	subs	T1, T1, #1
	bne	1b
4:
	cmp	U3, #1		@ check negative flag
	rsbeq	T0, T0, #0	@ yes, negate (r0 = 0 - r0)
5:
	pop	{U0,U1,U2,U3,lr}
	bx	lr





	defcode "FIND",4,,FIND
	POPPSP	T1			@ length of string
	POPPSP	T0			@ address of string
	bl	_FIND
	PUSHPSP	T0			@ address of dictionary entry (or 0)
	NEXT
_FIND:
	@ FIND (address: T0, length: T1) (address: T0)
	push	{U0,U1,U2,U3,lr}

	mov	T2, T1			@ length
	mov	T1, T0			@ address
	ldr	T0, =var_LATEST
	ldr	T0, [T0]		@ current dictionary pointer
1:
	cmp	T0, #0			@ NULL?
	beq	4f			@ end of list!

	ldrb	T3, [T0, #4]		@ flags+length field
	and	T3, T3, #(F_HIDDEN|F_LENMASK)
	cmp	T3, T2			@ length the same? HUGE BUG T2, T2!!!
	bne	2f			@ nope, skip this entry

	@ T2 = T3, but T3 can be destroyed in the loop

	mov	U0, T1			@ current char in string A
	mov	U1, T0
	add	U1, U1, #5		@ current char in string B
10:
	ldrb 	U2, [U0], #1		@ char A, increment
	ldrb	U3, [U1], #1		@ char B, increment
	cmp	U2, U3			@ A = B?
	bne	2f			@ nope
	subs	T3, T3, #1		@ decrement
	bne	10b			@ > 0, keep going

	@ strings are equal, T0 is the correct entry pointer
	b	4f
2:
	ldr	T0, [T0]		@ previous dictionary pointer
	b	1b			@ try again
4:
	pop	{U0,U1,U2,U3,lr}
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
	ldrgtb	r4, [r0], #1	@ get character, increment
	strgtb	r4, [r3], #1	@ put character, increment header
	subs	r1, r1, #1	@ decrement length
	bpl	1b

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
	POPPSP	T1		@ length
	POPPSP	T0		@ address
	bl	_TELL
	NEXT
_TELL:
	mov	T2, T1		@ length
	mov	T1, T0		@ address
	mov	T0, #stdout
	mov	r7, #__NR_write
	svc	#0
	bx	lr

	defword "QUIT",4,,QUIT
	.int RZ,RSPSTORE	// R0 RSP!, clear the return stack
	.int INTERPRET		// interpret the next word
	.int BRANCH,-8		// and loop (indefinitely)





	defcode "INTERPRET",9,,INTERPRET
	mov	U3, #0			@ reset interpret_is_lit flag

	bl	_WORD			@ returns T0 = address, T1 = length
	mov	U0, T0			@ address
	mov	U1, T1			@ length
	bl	_FIND			@ returns T0 = dictionary entry
	cmp	T0, #0			@ = NULL?
	beq	1f			@ not found!

	@ found in dictionary, check if it's immediate
	ldrb	U2, [T0, #4]		@ load length/flags byte
	bl	_TCFA			@ returns T0 = codeword pointer 
	tst	U2, #F_IMMED		@ test immediate flag
	bne	4f			@ jump straight to execute!
	b	2f			@ jump to compile/execute?

1:	@ not in dictionary, check if it's a number
	add	U3, U3, #1		@ set interpret_is_lit flag
	mov	T0, U0			@ address
	mov	T1, U1			@ length
	bl	_NUMBER			@ returns T0 = number, T1 = unparsed
	cmp	T1, #0			@ unparsed > 0?
	bne	6f			@ error!

	mov	U2, T0			@ number
	ldr	T0, =LIT		@ codeword is LIT

2:	@ compiling or executing?
	ldr	T2, =var_STATE		@ address of STATE
	ldr	T2, [T2]		@ value of STATE
	cmp	T2, #0			@ STATE == 0?
	beq	4f			@ jump straight to execute!

	@ compiling, append word to current dictionary definition
	bl	_COMMA			@ expects codeword in T0
	cmp	U3, #0			@ interpret_is_lit == 0?
	beq	3f			@ yep, so we're done

	mov	T0, U2			@ number
	bl	_COMMA			@ expects codeword in T0
3:
	NEXT


4:	@ executing, so run the word
	cmp	U3, #0			@ interpret_is_lit != 0?
	bne	5f			@ yep, so let's push

	@ not a literal, execute! never returns, but eventually NEXT will get
	@ called and reenter the loop in QUIT
	ldr	T1, [T0]
	bx	T1

5:	@ execute literal, which means push it
	PUSHPSP	U2
	NEXT

6:
	@ parse error, print context from input buffer
	mov	T0, #stderr
	ldr	T1, =errmsg		@ address
	mov	T2, #errmsgend-errmsg	@ length
	mov	r7, #__NR_write
	svc	#0

	mov	T0, #stderr
	ldr	T1, =currkey		@ address of currkey
	ldr	T1, [T1]		@ value of currkey, pointer in buffer
	ldr	T2, =buffer		@ address of buffer
	sub	T2, T1, T2		@ length = currkey - buffer
	cmp	T2, #40			@ > 40?
	movgt	T2, #40			@ cap at 40
	sub	T1, T1, T2		@ buffer_to_print = currkey - capped_length
	mov	r7, #__NR_write
	svc	#0

	mov	T0, #stderr
	ldr	T1, =errmsgnl		@ address
	mov	T2, #1			@ length
	mov	r7, #__NR_write
	svc	#0
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


	defcode "SYSCALL3",8,,SYSCALL3
	POPPSP	r7		@ syscall number
	POPPSP	r0		@ first parameter
	POPPSP	r1		@ second parameter
	POPPSP	r2		@ third parameter
	svc	#0
	PUSHPSP	r0		@ result
	NEXT

	defcode "SYSCALL2",8,,SYSCALL2
	POPPSP	r7		@ syscall number
	POPPSP	r0		@ first parameter
	POPPSP	r1		@ second parameter
	svc	#0
	PUSHPSP	r0		@ result
	NEXT

	defcode "SYSCALL1",8,,SYSCALL1
	POPPSP	r7		@ syscall number
	POPPSP	r0		@ first parameter
	svc	#0
	PUSHPSP	r0		@ result
	NEXT

	defcode "SYSCALL0",8,,SYSCALL0
	POPPSP	r7		@ syscall number
	svc	#0
	PUSHPSP	r0		@ result
	NEXT

	.text
	.set INITIAL_DATA_SEGMENT_SIZE,65536
set_up_data_segment:
@ current setup for debugging
	ldr	r0, =data_segment
	ldr	r1, =var_HERE
	str	r0, [r1]
	bx	lr
@ original code to make data segment extensible
@	mov	r0, #0
@	svc	__NR_brk
@	ldr	r1, =var_HERE
@	str	r0, [r1]
@	add	r0, r0, #INITIAL_DATA_SEGMENT_SIZE
@	svc	__NR_brk
@	bx	lr

	.set RETURN_STACK_SIZE,8192
	.set BUFFER_SIZE,4096

@ very basic debugging helper
	.text
debug_ping:
	stmfd	sp!, {r0-r12}
	mov	r0, #stderr
	ldr	r1, =debugmsg		@ address
	mov	r2, #debugend-debugmsg	@ length
	mov	r7, #__NR_write
	svc	#0
	ldmfd	sp!, {r0-r12}
	bx	lr
	.section .rodata
debugmsg:
	.ascii "\nPING!\n"
debugend:

@ debugging helper for assembly words
@ expects address in T0, length in T1
@ controlled by PONG FORTH variable
@ use DONG word to toggle ON/OFF
	.text
debug_pong:
	mov	U0, T0
	mov	U1, T1

	ldr	T0, =var_PONG
	ldr	T0, [T0]
	cmp	T0, #0
	beq	1f

	mov	T0, #stderr
	ldr	T1, =rmsg		@ address
	mov	T2, #rmsgend-rmsg	@ length
	mov	r7, #__NR_write
	svc	#0

	mov	T0, #stderr
	mov	T1, U0
	mov	T2, U1
	mov	r7, #__NR_write
	svc	#0

	mov	T0, #stderr
	ldr	T1, =rmsgnl		@ address
	mov	T2, #1			@ length
	mov	r7, #__NR_write
	svc	#0
1:
	bx	lr

	.section .rodata
rmsg: .ascii "PONG: "
rmsgend:
rmsgnl: .ascii "\n"


	.bss
	.align 12
return_stack:
	.space RETURN_STACK_SIZE
return_stack_top:

	.align 12
buffer:
	.space BUFFER_SIZE

@ current setup for debugging, not extensible
	.align	12
data_segment:
	.space	INITIAL_DATA_SEGMENT_SIZE

	.text
	.align 2
@ from http://thinkingeek.com/2013/08/11/arm-assembler-raspberry-pi-chapter-15/
unsigned_longdiv:
    /* r0 contains N */
    /* r1 contains D */
    /* r2 contains Q */
    /* r3 contains R */
    push {r4, lr}
    mov r2, #0                 /* r2 ← 0 */
    mov r3, #0                 /* r3 ← 0 */

    mov r4, #32                /* r4 ← 32 */
    b .Lloop_check1
    .Lloop1:
        movs r0, r0, LSL #1    /* r0 ← r0 << 1 updating cpsr (sets C if 31st bit of r0 was 1) */
        adc r3, r3, r3         /* r3 ← r3 + r3 + C. This is equivalent to r3 ← (r3 << 1) + C */

        cmp r3, r1             /* compute r3 - r1 and update cpsr */
        subhs r3, r3, r1       /* if r3 >= r1 (C=1) then r3 ← r3 - r1 */
        adc r2, r2, r2         /* r2 ← r2 + r2 + C. This is equivalent to r2 ← (r2 << 1) + C */
    .Lloop_check1:
        subs r4, r4, #1        /* r4 ← r4 - 1 */
        bpl .Lloop1            /* if r4 >= 0 (N=0) then branch to .Lloop1 */

    pop {r4, lr}
    bx lr
