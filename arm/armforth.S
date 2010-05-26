@ armforth.S - Porting Richard Jones' FORTH to ARM
@
@ Copyright (c) 2010 by Peter H. Froehlich <phf@acm.org>
@ All right reserved.
@
@ Eventually there will be some kind of license here.

	.set JONES_VERSION,47
	.set ARM_VERSION,0

@ Register usage:
@
@ R13=SP	parameter stack pointer		PSP
@ R12		return stack pointer		RSP
@ R11		next instruction pointer	NIP
@ R10		scratch				SCR
@
@ Notes:
@
@ .align for x86 is bytes, for ARM it's powers of two

@ this hack is needed since .set doesn't seem to work?
#define PSP r13
#define RSP r12
#define NIP r11
#define SCR r10

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
	str	\reg, [PSP, #-4]!	@ store register into RSP-4, decrement RSP
	.endm

	.macro POPPSP reg
	ldr	\reg, [PSP], #4		@ load register from RSP, increment RSP
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
	PUSHPSP	r1
	NEXT

	defcode "-",1,,SUB
	POPPSP	r0
	POPPSP	r1
	sub	r0, r1, r0
	PUSHPSP	r1
	NEXT

	defcode "*",1,,MUL
	POPPSP	r0
	POPPSP	r1
	mul	r0, r1, r0
	PUSHPSP	r0
	NEXT






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
