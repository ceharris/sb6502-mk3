
		.include "exec.h.s"
		.include "stdio.h.s"

		.segment "JMPTAB"
		jmp exec
		jmp cwaitc
		jmp cgetc
		jmp cgets
		jmp cputc
		jmp cputs
