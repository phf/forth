@ armforth.S - Porting Richard Jones' FORTH to ARM
@
@ Copyright (c) 2010 by Peter H. Froehlich <phf@acm.org>
@ All right reserved.
@
@ Eventually there will be some kind of license here.

	.set JONES_VERSION,47
	.set ARM_VERSION,0

@ ARM conventions
@ ===============
@
@ It's ridicilously complicated to google for decent
@ information about the exact ABI details for Linux
@ on ARM. Until proven wrong, I'll assume that even
@ Linux adheres to the "official" ABI specification.
@ That one roughly says this:
@
@ register	aliases		notes
@
@ r15		pc		program counter
@ r14		lr		link register
@ r13		sp		stack pointer
@ r12		ip		linker scratch
@ r11		v8		variable
@ r10		v7		variable
@ r9		v6/sb/tr	variable/platform special
@ r8		v5		variable
@ r7		v4		variable/EABI special*
@ r6		v3		variable
@ r5		v2		variable
@ r4		v1		variable
@ r3		a4		argument/scratch
@ r2		a3		argument/scratch
@ r1		a2		argument/result/scratch
@ r0		a1		argument/result/scratch
@
@ *ARM Linux EABI uses r7 for the system call number,
@  making r7 "special" too. :-/
@ 
@ Registers v1-v8 and sp are usually callee saved,
@ except of course if they are "special". Registers
@ a1-a4 and lr seem to be caller saved.
@
@ Register usage
@ ==============
@
@ From the mess above we derive the following register
@ conventions for FORTH:
@
@ register	mnemonic	notes
@ r13/sp	PSP		parameter stack pointer
@ r11/v8	RSP		return stack pointer
@ r10/v7	NIP		next instruction pointer
@  r8/v5	SCR		scratch used in NEXT/DOCOL
@				TODO: maybe we don't need this?
@  r0-r6	-		various temporaries we need
@
@ We simply try to stay clear of all the "special" stuff,
@ which still leaves us with enough room to play.
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
#define SCR r8

	.macro NEXT
	ldr	SCR, [NIP], #4		@ load address from NIP, increment NIP
	bx	SCR			@ jump to address
	.endm

	.macro PUSHRSP reg
	str	\reg, [RSP, #-4]!	@ store register into RSP-4, decrement RSP
	.endm

	.macro POPRSP reg
	ldr	\reg, [RSP], #4		@ load register from RSP, increment RSP
	.endm

	.macro PUSHPSP reg
	str	\reg, [PSP, #-4]!	@ store register into PSP-4, decrement PSP
	.endm

	.macro POPPSP reg
	ldr	\reg, [PSP], #4		@ load register from PSP, increment PSP
	.endm


	.text
	.align 2
DOCOL:
	PUSHRSP	NIP			@ push NIP on return stack
	add	SCR, SCR, #4		@ we come from NEXT, SCR is the codeword, so
	mov	NIP, SCR		@ make NIP the first dataword
	NEXT

	.text
	.global	_start
_start:
	mov	r0, #0
	svc     0x900000+1		@ syscall exit

	.text
	.globl _fart
_fart:
	ldr	r0, =var_S0		@ save initial parameter stack pointer
	str	PSP, [r0]		@ save initial parameter stack pointer
	ldr	RSP, =return_stack_top	@ initialize return stack
@	call set_up_data_segment
	ldr	NIP, =cold_start	@ initialize interpreter
	NEXT				@ RUN! :-D

	.section .rodata
cold_start:
	.int QUIT

	.set F_IMMED,0x80
	.set F_HIDDEN,0x20
	.set F_LENMASK,0x1f

	// Store the chain of links.
	.set link,0

	.macro defword name, namelen, flags=0, label
	.section .rodata
	.align 2
	.globl name_\label
name_\label :
	.int link
	.set link,name_\label
	.byte \flags+\namelen
	.ascii "\name"
	.align 	2
	.globl \label
\label :
	.int DOCOL
	@ list of word pointers follows
	.endm

	.macro defcode name, namelen, flags=0, label
	.section .rodata
	.align 2
	.globl name_\label
name_\label :
	.int link
	.set link,name_\label
	.byte \flags+\namelen
	.ascii "\name"
	.align 2
	.globl \label
\label :
	.int code_\label
	.text
	@.align 4 @ TODO commented out in original?
	.globl code_\label
code_\label :
	@ assembler code follows
	.endm

	defcode "DROP",4,,DROP
	add PSP, PSP, #4		@ POPPSP would load the word
	NEXT

	defcode "SWAP",4,,SWAP
	POPPSP	r0
	POPPSP	r1
	PUSHPSP	r0
	PUSHPSP	r1
	NEXT

	defcode "DUP",3,,DUP
	ldr	r0, [PSP]
	PUSHPSP	r0
	NEXT

	defcode "OVER",4,,OVER
	ldr	r0, [PSP, #4]
	PUSHPSP	r0
	NEXT

	defcode "ROT",3,,ROT
	POPPSP	r0
	POPPSP	r1
	POPPSP	r2
	PUSHPSP	r1
	PUSHPSP	r0
	PUSHPSP	r2
	NEXT

	defcode "-ROT",4,,NROT
	POPPSP	r0
	POPPSP	r1
	POPPSP	r2
	PUSHPSP	r0
	PUSHPSP	r2
	PUSHPSP	r1
	NEXT

	defcode "2DROP",5,,TWODROP
	add PSP, PSP, #8		@ POPPSP would load the word
	NEXT

	defcode "2DUP",4,,TWODUP
	ldr	r0, [PSP]
	ldr	r1, [PSP, #4]
	PUSHPSP	r1
	PUSHPSP	r0
	NEXT

	defcode "2SWAP",5,,TWOSWAP
	POPPSP	r0
	POPPSP	r1
	POPPSP	r2
	POPPSP	r3
	PUSHPSP	r1
	PUSHPSP	r0
	PUSHPSP	r3
	PUSHPSP	r2
	NEXT

	defcode "?DUP",4,,QDUP
	ldr	r0, [PSP]
	cmp	r0, #0
	strne	r0, [PSP, #-4]!		@ look ma, no branch! PUSHPSP wouldn't be conditional
	NEXT

	defcode "1+",2,,INCR
	ldr	r0, [PSP]
	add	r0, r0, #1
	str	r0, [PSP]
	NEXT

	defcode "1-",2,,DECR
	ldr	r0, [PSP]
	sub	r0, r0, #1
	str	r0, [PSP]
	NEXT

	defcode "4+",2,,INCR4
	ldr	r0, [PSP]
	add	r0, r0, #4
	str	r0, [PSP]
	NEXT

	defcode "4-",2,,DECR4
	ldr	r0, [PSP]
	sub	r0, r0, #4
	str	r0, [PSP]
	NEXT

	defcode "+",1,,ADD
	POPPSP	r0
	POPPSP	r1
	add	r0, r1, r0
	PUSHPSP	r0
	NEXT

	defcode "-",1,,SUB
	POPPSP	r0
	POPPSP	r1
	sub	r0, r1, r0
	PUSHPSP	r0
	NEXT

	defcode "*",1,,MUL
	POPPSP	r0
	POPPSP	r1
	mul	r0, r1, r0
	PUSHPSP	r0
	NEXT

	@ TODO this is FAKE for now
	defcode "/MOD",4,,DIVMOD
	POPPSP	r0
	POPPSP	r1
	mov	r0, #3
	mov	r1, #10
	PUSHPSP	r0		@ remainder
	PUSHPSP	r1		@ quotient
	NEXT

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
	ldr	r0, [NIP], #4
	PUSHPSP	r0
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
	bl	_KEY			@ return key in r0
	PUSHPSP	r0
	NEXT
_KEY:	@ kills r0-r4!
	ldr	r1, =currkey		@ address of currkey
	ldr	r3, [r1]		@ value of currkey
	ldr	r2, =bufftop		@ address of bufftop
	ldr	r4, [r2]		@ value of bufftop
	cmp	r3, r4
	bge	1f			@ need more input
	ldrb	r0, [r3], #1		@ load character and increment currkey
	str	r3, [r1]
	bx	lr			@ return
1:
	mov	r0, #0			@ stdin
	ldr	r1, =buffer		@ address of buffer
	ldr	r2, =currkey		@ address of currkey
	str	r1, [r2]		@ update currkey
	mov	r2, #BUFFER_SIZE	@ length
	svc	__NR_read
	cmp	r0, #0			@ check result
	ble	2f			@ error
	ldr	r1, =buffer		@ address of buffer
	add	r1, r1, r0		@ add length we read
	ldr	r2, =bufftop		@ address of bufftop
	str	r1, [r2]		@ update bufftop
	b	_KEY
2:
	svc	__NR_exit		@ exit

	.data
	.align 4
currkey:
	.int buffer		// Current place in input buffer (next character to read).
bufftop:
	.int buffer		// Last valid data in input buffer + 1.


	defcode "EMIT",4,,EMIT
	POPPSP	r0
	bl	_EMIT
	NEXT
_EMIT:
	ldr	r1, =emit_scratch	@ address of buffer
	strb	r0, [r1]		@ store byte in buffer

	mov	r0, #1			@ stdout
	mov	r2, #1			@ length
	svc	__NR_write
	bx	lr

	.data			// NB: easier to fit in the .data section
emit_scratch:
	.space 1		// scratch used by EMIT


	defcode "WORD",4,,WORD
	bl _WORD
	PUSHPSP	r0		@ address
	PUSHPSP	r1		@ length
	NEXT
_WORD:
	PUSHPSP	lr		@ we call _KEY so we need to save lr
1:
	bl	_KEY		@ key in r0
	cmp	r0, #'\\'	@ comment?
	beq	3f		@ skip comment
	cmp	r0, #' '	@ space?
	beq	1b		@ keep looking

	ldr	r5, =word_buffer	@ address
2:
	strb	r0, [r5], #1		@ store character, increment pointer
	bl	_KEY			@ key in r0
	cmp	r0, #' '		@ space?
	bne	2b			@ keep looking

	ldr	r0, =word_buffer	@ address
	sub	r1, r5, r0		@ length
	POPPSP	lr			@ restore lr
	bx	lr
3:
	bl	_KEY		@ key in r0
	cmp	r0, #'\n'	@ eof?
	bne	3b		@ keep looking
	b	1b

	.data			// NB: easier to fit in the .data section
word_buffer:
	.space 32


	defcode "NUMBER",6,,NUMBER
	POPPSP	r3		@ length of string
	POPPSP	r2		@ address of string
	bl	_NUMBER
	PUSHPSP	r0		@ number
	PUSHPSP	r1		@ # unparsed
	NEXT

_NUMBER:
	mov	r0, #0		@ number
	mov	r1, #0		@ # unparsed

	cmp	r3, #0		@ zero length?
	beq	5f		@ error!

	ldr	r4, =var_BASE
	ldr	r4, [r4]	@ get BASE

	ldrb	r5, [r2], #1	@ get character and increment address
	mov	r6, #0		@ set negative flag false
	cmp	r5, #'-'	@ leading '-'?
	bne	2f		@ nope, try to parse as digit

	mov	r6, #1		@ set negative flag true
	subs	r3, r3, #1	@ decrement length
	bne	1f		@ >0 so keep going

	mov	r1, #1		@ indicate error
	bx	lr
1:
	mul	r7, r0, r4	@ number = number * BASE
	mov	r0, r7		@ (need to use another register for mul to avoid warning)
	ldrb	r5, [r2], #1	@ get character and increment address
2:
	subs	r5, r5, #'0'	@ try lower digit bound
	blt	4f		@ nope, < '0' so we're done
	cmp	r5, #10		@ try upper digit bound
	blt	3f		@ yes, we got one!
	subs	r5, r5, #17	@ try lower char bound (17 is 'A'-'0')
	blt	4f		@ nope, < 'A' so we're done
	add	r5, r5, #10	@ adjust for first 10 digit values before 'A'
3:
	cmp	r5, r4		@ >= BASE?
	bge	4f		@ yep, we're done

	@ finally, add new digit to number and loop
	add	r0, r5
	subs	r3, r3, #1
	bne	1b
4:
	cmp	r6, #1		@ check negative flag
	rsbeq	r0, r0, #0	@ yes, negate (r0 = 0 - r0)
5:
	bx	lr



	.set RETURN_STACK_SIZE,8192
	.set BUFFER_SIZE,4096

	.bss
	.align 12
return_stack:
	.space RETURN_STACK_SIZE
return_stack_top:

	.align 12
buffer:
	.space BUFFER_SIZE
