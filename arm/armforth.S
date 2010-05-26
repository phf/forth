@ armforth.S - Porting Richard Jones' FORTH to ARM
@
@ Copyright (c) 2010 by Peter H. Froehlich <phf@acm.org>
@ All right reserved.
@
@ Eventually there will be some kind of license here.

@ Register usage (planned):
@
@ R13=SP parameter stack pointer  PSP
@ R12    return stack pointer     RSP
@ R11    next instruction pointer NIP
@ R0...  scratch

	.set JONES_VERSION,47
	.set ARM_VERSION,0

	.set PSP,r13
	.set RSP,r12
	.set NIP,r11

	.macro NEXT
	ldr	r0, [NIP], #4		@ load address from NIP, increment NIP
	bx	r0			@ jump to address
	.endm

	.macro PUSHRSP reg
	str	\reg, [RSP, #-4]!	@ store register into RSP-4, decrement RSP
	.endm

	.macro POPRSP reg
	ldr	\reg, [RSP], #4		@ load register from RSP, increment RSP
	.endm


	.text
	.global	main
@ should really be _start but can't make that work yet
main:
	mov	r0, #0
	bx	lr
