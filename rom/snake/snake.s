
		.include "ascii.h.s"
		.include "prog.h.s"
		.include "serial.h.s"
		.include "ui.h.s"

		.segment "CODE"
		.word PROG_MAGIC
		.byte 0
		.word start

start:
		cli
		jsr ser_init

		jsr ui_reset
		ldx #10
		ldy #10
		jsr ui_put_snake_segment
		inx
		jsr ui_put_snake_segment
		inx
		jsr ui_put_snake_segment
		inx
		jsr ui_put_snake_segment
		inx
		jsr ui_put_snake_segment
		iny
		jsr ui_put_snake_segment
		iny
		jsr ui_put_snake_segment
		iny
		jsr ui_put_snake_segment
		iny
		jsr ui_put_snake_segment

		jsr ser_flush

@done:
		bra @done
	


