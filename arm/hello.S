@ System calls in ARM Linux.
@
@ Back when I stopped hacking on armforth in 2010, different system call
@ conventions were apparently in place. Either that, or I just never figured
@ it out back then. In any case, this is how it's done in 2016.
@
@ See /usr/include/arm-linux-gnueabihf/asm/unistd.h for system call numbers.

#include <asm/unistd.h>

#define STDOUT_FILENO 1

	.data
hello:
	.ascii	"Hello World!\n"

	.text
	.global	_start
_start:
	mov	r7, #__NR_write
	mov	r0, #STDOUT_FILENO
	ldr	r1, =hello
	mov	r2, #13
	svc	#0

	mov	r7, #__NR_exit
	mov	r0, #0
	svc	#0
