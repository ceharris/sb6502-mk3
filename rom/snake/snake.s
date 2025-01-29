
		.include "ascii.h.s"
		.include "jmptab.h.s"
		.include "prog.h.s"
		.include "serial.h.s"
		.include "ui.h.s"

		.segment "CODE"
		.word PROG_MAGIC
		.byte 0
		.word start

start:
		sei
		jsr ser_init

		jsr ui_clear
		jsr ser_flush

		jmp J_IPL

	


