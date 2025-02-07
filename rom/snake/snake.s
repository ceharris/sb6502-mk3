
		.include "ascii.h.s"
		.include "display.h.s"
		.include "keys.h.s"
		.include "model.h.s"
		.include "prog.h.s"
		.include "serial.h.s"
		.include "state.h.s"

		.segment "MAGIC"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $84
		.word start

		.segment "CODE"
		.global start
start:
		jsr ser_init
		cli

		jsr model_init
		jsr ui_clear

@head:
		ldx snake_head_x
		ldy snake_head_y
		jsr ui_put_snake_segment
		jsr ser_flush
		jsr delay
		jsr model_next
		ldx snake_head_x
		ldy snake_head_y
		jsr ui_put_empty_segment
		lda next_x
		sta snake_head_x
		lda next_y
		sta snake_head_y
		jsr key_scan
		beq @head
		cmp #KEY_QUIT
		beq soft_reset
		cmp #KEY_REDRAW
		beq @redraw
		jsr model_key_event
		bra @head
@redraw:
		jsr ui_redraw
		bra @head		
delay:
		ldx #$80
@loop:
		iny
		bne @loop
		dex
		bne @loop
		rts
	
		.include "reset.s"	


