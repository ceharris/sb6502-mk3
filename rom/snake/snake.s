
		.include "ascii.h.s"
		.include "prog.h.s"
		.include "serial.h.s"
		.include "ui.h.s"

		.segment "MAGIC"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $84
		.word start

		.segment "CODE"
start:
		jsr ser_init

		jsr ui_clear
		jsr ser_flush

@halt:
		bra @halt
	


