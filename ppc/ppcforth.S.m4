;;; -*- mode: asm; comment-column: 40 -*-
;;; JONESFORTH ported to PowerPC on Mac OS X 10.3.9 by Tony Garnock-Jones <tonyg@kcbbs.gen.nz>
;;; m4 ppcforth.S.m4 > ppcforth.S && gcc -nostdlib -o ppcforth ppcforth.S && rm ppcforth.S
;;; Forth regs:
;;; Instruction pointer		r31	callee-saved
;;; Data stack pointer		r1			full descending
;;; Return stack pointer	r30	callee-saved	full descending
;;; Codeword pointer		r29	callee-saved
;;; Scratch			r12
changequote([, ])dnl

#include <sys/syscall.h>

	.set	RETURN_STACK_SIZE, 8192
	.set	BUFFER_SIZE,4096
	.set	USER_DEFS_SIZE,65536

;;; ---------------------------------------------------------------------------
;;; Macros

	.set	GARNOCKJONES_VERSION,14641

define([NEXT],
	[lwz	r29,0(r31)
	addi	r31,r31,4
	lwz	r12,0(r29)
	mtctr	r12
	bctr])

define([PUSHRSP],
	[stwu	]$1[,-4(r30)])

define([POPRSP],
	[lwz	]$1[,0(r30)
	addi	r30,r30,4])

define([PUSHDSP],
	[stwu	]$1[,-4(r1)])

define([POPDSP],
	[lwz	]$1[,0(r1)
	addi	r1,r1,4])

define([PEEKDSP],
	[lwz	]$1[,(4*]$2[)(r1)])

define([ADDROF],
	[addis	]$1[,0,hi16(]$2[)
	ori	]$1[,]$1[,lo16(]$2[)])

define([LOADFROM],
	[addis	]$1[,0,ha16(]$2[)
	lwz	]$1[,lo16(]$2[)(]$1[)])

define([STORETO],
	[addis	]$3[,0,ha16(]$2[)
	stw	]$1[,lo16(]$2[)(]$3[)])

	.set F_IMMED, 0x80
	.set F_HIDDEN, 0x20
	.set F_LENMASK, 0x1f

define([DictionaryLink], [0])

define([DEFWORD],
	[.const_data
	.align	2
	.globl	name_]$4[
name_]$4[:
	.long	DictionaryLink[]define([DictionaryLink], name_]$4[)
	.byte	]$3[+]$2[
	.ascii	]$1[
	.align	2
	.globl	]$4[
]$4[:
	.long	DOCOL])

define([DEFCODE],
	[.const_data
	.align	2
	.globl	name_]$4[
name_]$4[:
	.long	DictionaryLink[]define([DictionaryLink], name_]$4[)
	.byte	]$3[+]$2[
	.ascii	]$1[
	.align	2
	.globl	]$4[
]$4[:
	.long	code_]$4[
	.text
	.align	2
	.globl	code_]$4[
code_]$4[:])

define([DEFBINOP],
	[DEFCODE(]$1[,]$2[,]$3[,]$4[)
	POPDSP(r4)
	lwz	r3,0(r1)
	]$5[	r3,r4,r3
	stw	r3,0(r1)
	NEXT])

define([DEFPREDICATE],
	[DEFCODE(]$1[,]$2[,]$3[,]$4[)
	POPDSP(r4)
	lwz	r3,0(r1)
	cmpw	r3,r4
	]$5[	1f
	li	r3,0
	stw	r3,0(r1)
	NEXT
1:	li	r3,1
	stw	r3,0(r1)
	NEXT])

define([DEFZPREDICATE],
	[DEFCODE(]$1[,]$2[,]$3[,]$4[)
	lwz	r3,0(r1)
	cmpwi	r3,0
	]$5[	1f
	li	r3,0
	stw	r3,0(r1)
	NEXT
1:	li	r3,1
	stw	r3,0(r1)
	NEXT])

define([DEFVAR],
	[DEFCODE(]$1[,]$2[,]$3[,]$4[)
	ADDROF(r3,var_]$4[)
	PUSHDSP(r3)
	NEXT
	.data
	.align	2
var_]$4[:	.long	]$5[])

define([DEFCONST],
	[DEFCODE(]$1[,]$2[,]$3[,]$4[)
	ADDROF(r3,]$5[)
	PUSHDSP(r3)
	NEXT])

;;; ---------------------------------------------------------------------------
;;; Text

	.text
	.align	2

start:
	ADDROF(r12,var_SZ)
	stw	r1,0(r12)
	ADDROF(r30,return_stack_top)
	ADDROF(r31,cold_start)
	NEXT

exit_success:
	li	r3,0
	li	r0,SYS_exit
	sc
	nop
	;; Fall through
syscall_failed:
	li	r3,1
	li	r0,SYS_exit
	sc
	nop
	;; Deliberate alignment fault to force process death
	li	r3,1
	lwz	r3,0(r3)
	b	syscall_failed

DOCOL:
	PUSHRSP(r31)
	addi	r31,r29,4
	NEXT

	DEFCODE("DUP",3,0,DUP)
	lwz	r3,0(r1)
	PUSHDSP(r3)
	NEXT

	DEFCODE("DROP",4,0,DROP)
	addi	r1,r1,4
	NEXT

	DEFCODE("SWAP",4,0,SWAP)
	lwz	r3,0(r1)
	lwz	r4,4(r1)
	stw	r3,4(r1)
	stw	r4,0(r1)
	NEXT

	DEFCODE("OVER",4,0,OVER)
	lwz	r3,4(r1)
	PUSHDSP(r3)
	NEXT

	DEFCODE("ROT",3,0,ROT)
	lwz	r3,0(r1)
	lwz	r4,4(r1)
	lwz	r5,8(r1)
	stw	r3,8(r1)
	stw	r5,4(r1)
	stw	r4,0(r1)
	NEXT

	DEFCODE("-ROT",4,0,NROT)
	lwz	r3,0(r1)
	lwz	r4,4(r1)
	lwz	r5,8(r1)
	stw	r4,8(r1)
	stw	r3,4(r1)
	stw	r5,0(r1)
	NEXT

	DEFCODE("?DUP",4,0,QDUP)
	lwz	r3,0(r1)
	cmpwi	r3,0
	beq	1f
	PUSHDSP(r3)
1:	NEXT

	DEFCODE("1+",2,0,INCR)
	lwz	r3,0(r1)
	addi	r3,r3,1
	stw	r3,0(r1)
	NEXT

	DEFCODE("1-",2,0,DECR)
	lwz	r3,0(r1)
	addi	r3,r3,-1
	stw	r3,0(r1)
	NEXT

	DEFCODE("4+",2,0,INCR4)
	lwz	r3,0(r1)
	addi	r3,r3,4
	stw	r3,0(r1)
	NEXT

	DEFCODE("4-",2,0,DECR4)
	lwz	r3,0(r1)
	addi	r3,r3,-4
	stw	r3,0(r1)
	NEXT

	DEFBINOP("+",1,0,ADD,add)
	DEFBINOP("-",1,0,SUB,subf)
	DEFBINOP("*",1,0,MUL,mullw)

	DEFCODE("/MOD",4,0,DIVMOD)
	POPDSP(r4)
	lwz	r3,0(r1)
	divw	r5,r3,r4
	mullw	r6,r5,r4
	subf	r6,r6,r3
	stw	r6,0(r1)
	PUSHDSP(r5)
	NEXT

	DEFPREDICATE("=",1,0,EQU,beq)
	DEFPREDICATE("<>",2,0,NEQU,bne)
	DEFPREDICATE("<",1,0,LT,blt)
	DEFPREDICATE(">",1,0,GT,bgt)
	DEFPREDICATE("<=",2,0,LE,ble)
	DEFPREDICATE(">=",2,0,GE,bge)

	DEFZPREDICATE("0=",2,0,ZEQU,beq)
	DEFZPREDICATE("0<>",3,0,ZNEQU,bne)
	DEFZPREDICATE("0<",2,0,ZLT,blt)
	DEFZPREDICATE("0>",2,0,ZGT,bgt)
	DEFZPREDICATE("0<=",3,0,ZLE,ble)
	DEFZPREDICATE("0>=",3,0,ZGE,bge)

	DEFBINOP("AND",3,0,AND,and)
	DEFBINOP("OR",2,0,OR,or)
	DEFBINOP("XOR",3,0,XOR,xor)

	DEFCODE("INVERT",6,0,INVERT)
	lwz	r3,0(r1)
	not	r3,r3
	stw	r3,0(r1)
	NEXT

	DEFCODE("EXIT",4,0,EXIT)
	POPRSP(r31)
	NEXT

	DEFCODE("LIT",3,0,LIT)
	lwz	r3,0(r31)
	addi	r31,r31,4
	PUSHDSP(r3)
	NEXT

	DEFCODE("!",1,0,STORE)
	POPDSP(r4)
	POPDSP(r3)
	stw	r3,0(r4)
	NEXT

	DEFCODE("\100",1,0,FETCH)
	lwz	r4,0(r1)
	lwz	r3,0(r4)
	stw	r3,0(r1)
	NEXT

	DEFCODE("+!",2,0,ADDSTORE)
	POPDSP(r4)
	POPDSP(r3)
	lwz	r5,0(r4)
	add	r5,r3,r5
	stw	r5,0(r4)
	NEXT

	DEFCODE("-!",2,0,SUBSTORE)
	POPDSP(r4)
	POPDSP(r3)
	lwz	r5,0(r4)
	subf	r5,r3,r5
	stw	r5,0(r4)
	NEXT

	DEFCODE("C!",2,0,STOREBYTE)
	POPDSP(r4)
	POPDSP(r3)
	stb	r3,0(r4)
	NEXT

	DEFCODE("C\100",2,0,FETCHBYTE)
	lwz	r4,0(r1)
	lbz	r3,0(r4)
	stw	r3,0(r1)
	NEXT

	DEFVAR("STATE",5,0,STATE,0)
	DEFVAR("HERE",4,0,HERE,user_defs_start)
	DEFVAR("LATEST",6,0,LATEST,name_SYSEXIT)
	DEFVAR("_X",2,0,TX,0)
	DEFVAR("_Y",2,0,TY,0)
	DEFVAR("_Z",2,0,TZ,0)
	DEFVAR("S0",2,0,SZ,0)
	DEFVAR("BASE",4,0,BASE,10)

	DEFCONST("VERSION",7,0,VERSION,GARNOCKJONES_VERSION)
	DEFCONST("R0",2,0,RZ,return_stack)
	DEFCONST("DOCOL",5,0,__DOCOL,DOCOL)
	DEFCONST("F_IMMED",7,0,__F_IMMED,F_IMMED)
	DEFCONST("F_HIDDEN",8,0,__F_HIDDEN,F_HIDDEN)
	DEFCONST("F_LENMASK",9,0,__F_LENMASK,F_LENMASK)

	DEFCODE(">R",2,0,TOR)
	POPDSP(r3)
	PUSHRSP(r3)
	NEXT

	DEFCODE("R>",2,0,FROMR)
	POPRSP(r3)
	PUSHDSP(r3)
	NEXT

	DEFCODE("RSP\100",4,0,RSPFETCH)
	PUSHDSP(r30)
	NEXT

	DEFCODE("RSP!",4,0,RSPSTORE)
	POPDSP(r30)
	NEXT

	DEFCODE("RDROP",5,0,RDROP)
	addi	r30,r30,4
	NEXT

	DEFCODE("DSP\100",4,0,DSPFETCH)
	PUSHDSP(r1)
	NEXT

	DEFCODE("DSP!",4,0,DSPSTORE)
	lwz	r1,0(r1)
	NEXT

	DEFCODE("KEY",3,0,KEY)
	bl	_KEY
	PUSHDSP(r3)
	NEXT

_KEY:	LOADFROM(r3,currkey)
	LOADFROM(r4,bufftop)
	cmpw	r3,r4
	bge	1f
	lbz	r4,0(r3)
	addi	r3,r3,1
	STORETO(r3,currkey,r5)
	mr	r3,r4
	blr

1:	li	r3,0
	ADDROF(r4,buffer)
	STORETO(r4,currkey,r5)
	li	r5,BUFFER_SIZE
	li	r0,SYS_read
;;; From http://uninformed.org/?v=1&a=1&t=txt :
;; "An interesting feature of Mac OS X is that a successful system call will return
;; to the address 4 bytes after the end of 'sc' instruction and a failed system
;; call will return directly after the 'sc' instruction. This allows you to
;; execute a specific instruction only when the system call fails. The most common
;; application of this feature is to branch to an error handler, although it can
;; also be used to set a flag or a return value."
	sc
	b	syscall_failed
	cmpwi	r3,0
	;; Exit on EOF.
	beq	exit_success
	ADDROF(r4,buffer)
	add	r3,r4,r3
	STORETO(r3,bufftop,r4)
	b	_KEY

	DEFCODE("EMIT",4,0,EMIT)
	POPDSP(r3)
	bl	_EMIT
	NEXT

_EMIT:	ADDROF(r4,emit_scratch_buffer)
	stb	r3,0(r4)
	li	r3,1
	li	r5,1
	li	r0,SYS_write
	sc
	b	syscall_failed
	blr

	DEFCODE("WORD",4,0,WORD)
	bl	_WORD
	PUSHDSP(r3)
	PUSHDSP(r4)
	NEXT

_WORD:	mflr	r28
1:	bl	_KEY
	cmpwi	r3,92			; backslash
	beq	3f
	cmpwi	r3,32			; space (also other ctl chars)
	ble	1b

	;; r3 holds first nonblank, noncontrol, noncomment char
	ADDROF(r27,word_buffer)
	li	r26,0
2:	stbx	r3,r27,r26
	addi	r26,r26,1
	bl	_KEY
	cmpwi	r3,32			; space (also other ctl chars)
	bgt	2b

	mr	r3,r27
	mr	r4,r26
	mtlr	r28
	blr

	;; skip comments
3:	bl	_KEY
	cmpwi	r3,10			; \n
	beq	1b
	cmpwi	r3,13			; \r
	beq	1b
	b	3b

	DEFCODE("SNUMBER",7,0,SNUMBER)
	POPDSP(r4)
	POPDSP(r3)
	bl	_SNUMBER
	PUSHDSP(r3)
	NEXT

	.globl	_SNUMBER
_SNUMBER:
	mtctr	r4
	li	r5,0
1:	mulli	r5,r5,10
	lbz	r6,0(r3)
	addi	r6,r6,-48		; subtract '0'
	add	r5,r5,r6
	addi	r3,r3,1
	bc	16,0,1b			; AIX calls this "bdn 1b". Dec CTR, branch if nonzero.
	mr	r3,r5
	blr

	DEFCODE("FIND",4,0,FIND)
	POPDSP(r4)
	POPDSP(r3)
	bl	_FIND
	PUSHDSP(r3)
	NEXT

	.globl	_FIND
_FIND:	LOADFROM(r5,var_LATEST)
1:	cmpwi	r5,0
	beq	4f

	lbz	r6,4(r5)
	andi.	r6,r6,(F_HIDDEN|F_LENMASK)
	cmpw	r6,r4
	bne	2f

	mtctr	r4
	li	r6,5
	li	r7,0

3:	lbzx	r8,r5,r6
	lbzx	r9,r3,r7
	cmpw	r8,r9
	bne	2f
	addi	r6,r6,1
	addi	r7,r7,1
	bc	16,0,3b			; dec CTR, branch if nonzero

4:	mr	r3,r5
	blr

2:	lwz	r5,0(r5)
	b	1b

	DEFCODE(">CFA",4,0,TCFA)
	lwz	r3,0(r1)
	bl	_TCFA
	stw	r3,0(r1)
	NEXT

_TCFA:	lbz	r4,4(r3)
	andi.	r4,r4,F_LENMASK
	addi	r4,r4,(4+1+3)
	andi.	r4,r4,(~3&0xFFFF)
	add	r3,r3,r4
	blr

	DEFWORD(">DFA",4,0,TDFA)
	.long	TCFA,INCR4,EXIT

	DEFCODE("CREATE",6,0,CREATE)
	bl	_WORD

	LOADFROM(r5,var_HERE)
	LOADFROM(r6,var_LATEST)
	stw	r6,0(r5)
	stb	r4,4(r5)

	mtctr	r4
	addi	r5,r5,5
1:	lbz	r6,0(r3)
	stb	r6,0(r5)
	addi	r3,r3,1
	addi	r5,r5,1
	bc	16,0,1b			; dec CTR, branch if nonzero

	addi	r5,r5,3
	andi.	r5,r5,(~3&0xFFFF)

	LOADFROM(r6,var_HERE)
	STORETO(r6,var_LATEST,r7)
	STORETO(r5,var_HERE,r7)
	NEXT

	DEFCODE("\054",1,0,COMMA)	; comma
	POPDSP(r3)
	bl	_COMMA
	NEXT

_COMMA:	ADDROF(r5,var_HERE)
	lwz	r4,0(r5)
	stw	r3,0(r4)
	addi	r4,r4,4
	stw	r4,0(r5)
	blr

	DEFCODE("\133",1,F_IMMED,LBRAC)	; left bracket
	li	r3,0
	STORETO(r3,var_STATE,r4)
	NEXT

	DEFCODE("\135",1,0,RBRAC) ; right bracket
	li	r3,1
	STORETO(r3,var_STATE,r4)
	NEXT

	DEFWORD(":",1,0,COLON)
	.long	CREATE,LIT,DOCOL,COMMA,LATEST,FETCH,HIDDEN,RBRAC,EXIT

	DEFWORD("\073",1,F_IMMED,SEMICOLON) ; semicolon
	.long	LIT,EXIT,COMMA,LATEST,FETCH,HIDDEN,LBRAC,EXIT

	DEFCODE("IMMEDIATE",9,F_IMMED,IMMEDIATE)
	LOADFROM(r3,var_LATEST)
	lbz	r4,4(r3)
	xori	r4,r4,F_IMMED
	stb	r4,4(r3)
	NEXT

	DEFCODE("HIDDEN",6,0,HIDDEN)
	POPDSP(r3)
	lbz	r4,4(r3)
	xori	r4,r4,F_HIDDEN
	stb	r4,4(r3)
	NEXT

	DEFCODE("'",1,0,TICK)
	lwz	r3,0(r31)
	addi	r31,r31,4
	PUSHDSP(r3)
	NEXT

	DEFCODE("BRANCH",6,0,BRANCH)
	lwz	r3,0(r31)
	add	r31,r31,r3
	NEXT

	DEFCODE("0BRANCH",7,0,ZBRANCH)
	POPDSP(r3)
	cmpwi	r3,0
	beq	code_BRANCH
	addi	r31,r31,4
	NEXT

	DEFCODE("LITSTRING",9,0,LITSTRING)
	lwz	r3,0(r31)
	addi	r31,r31,4
	PUSHDSP(r31)
	PUSHDSP(r3)
	add	r31,r31,r3
	addi	r31,r31,3
	andi.	r31,r31,(~3&0xFFFF)
	NEXT

	DEFCODE("TELL",4,0,TELL)
	POPDSP(r4)
	POPDSP(r3)
	bl	_TELL
	NEXT

_TELL:	mr	r5,r4
	mr	r4,r3
	li	r3,1
	li	r0,SYS_write
	sc
	b	syscall_failed
	blr

	DEFWORD("COLD",4,0,COLD)
	.long	INTERPRETER,LIT,1,SYSEXIT

	DEFWORD("INTERPRETER",11,0,INTERPRETER)
	.long	INTERPRET,RDROP,INTERPRETER

	DEFCODE("INTERPRET",9,0,INTERPRET)
 	bl	_WORD
	mr	r27,r3

	li	r28,0
	bl	_FIND
	cmpwi	r3,0
	beq	1f

	lbz	r5,4(r3)
	bl	_TCFA
	andi.	r5,r5,F_IMMED
	bne	4f
	b	2f

1:	li	r28,1
	mr	r3,r27
	bl	_SNUMBER
	mr	r27,r3
	ADDROF(r3,LIT)

	;; At this point,
	;; - r3 is code to compile (maybe LIT, if r28 nonzero)
	;; - if r28 ("interpret_is_lit") is nonzero, r27 is literal number to compile
2:	LOADFROM(r4,var_STATE)
	cmpwi	r4,0
	beq	4f

	bl	_COMMA
	cmpwi	r28,0
	beq	3f
	mr	r3,r27
	bl	_COMMA
3:	NEXT

4:	cmpwi	r28,0
	bne	5f

	mr	r29,r3
	lwz	r12,0(r29)
	mtctr	r12
	bctr

5:	PUSHDSP(r27)
	NEXT

	DEFCODE("CHAR",4,0,CHAR)
	bl	_WORD
	lbz	r3,0(r3)
	PUSHDSP(r3)
	NEXT

	DEFCODE("SYSEXIT",7,0,SYSEXIT)
	POPDSP(r3)
	li	r0,SYS_exit
	sc
	nop
	b	syscall_failed

;;; ---------------------------------------------------------------------------
;;; Data

	.data

	.align	2
cold_start:
	.long	COLD

emit_scratch_buffer:
	.byte	0

	.align	2
word_buffer:
	.space	64

;;; ---------------------------------------------------------------------------
;;; BSS

	.data
	.align	2

	.align	12
return_stack:
	.space	RETURN_STACK_SIZE
return_stack_top:

	.align	12
buffer:
	.space	BUFFER_SIZE
buffer_top:
currkey:
	.long	buffer
bufftop:
	.long	buffer

	.align	12
user_defs_start:
	.space	USER_DEFS_SIZE
