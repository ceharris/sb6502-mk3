
		.include "ascii.h.s"
		.include "model.h.s"
		.include "prog.h.s"
		.include "serial.h.s"
		.include "state.h.s"
		.include "ui.h.s"

		.segment "MAGIC"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $84
		.word start

		.segment "CODE"
start:
		jsr ser_init

		jsr ui_clear

		lda #GF_AXIS_VERTICAL | GF_OP_DECREMENT
		sta game_flags
		lda #20
		sta snake_head_x
		lda #11
		sta snake_head_y
@head:
		ldx snake_head_x
		ldy snake_head_y
		jsr ui_put_snake_segment
		jsr ser_flush
		jsr delay
		jsr next_state
		lda next_x
		sta snake_head_x
		lda next_y
		sta snake_head_y
		bra @head

delay:
		ldx #$80
		ldy #0
@loop:
		iny
		bne @loop
		dex
		bne @loop
		rts
	
halt:
		bra halt
	


