	.ifndef STDIO_H
		STDIO_H = 1

		.include "acia.h.s"
		cinit = acia_init
		cgetc = acia_getc
		cwaitc = acia_waitc

		.global cputc
		.global cgets
		.global cputs
	.endif