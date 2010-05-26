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
