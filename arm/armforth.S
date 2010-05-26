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


	.text
	.align 4
DOCOL:
	PUSHRSP	NIP			@ push NIP on return stack
	add	SCR, SCR, #4		@ we come from NEXT, SCR is the codeword, so
	mov	NIP, SCR		@ make NIP the first dataword
	NEXT


	.text
	.global	main
@ should really be _start but can't make that work yet
main:
	mov	r0, #0
	bx	lr
