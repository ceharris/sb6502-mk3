		.include "ascii.h.s"
		.include "keys.h.s"
		.include "serial.h.s"

		.segment "CODE"

key_scan:
		jsr ser_getc 
		bcc @none
		cmp #ESC
		beq @check_esc
		cmp #'a'
		bcc @check_key
		cmp #'z'+1
		bcs @check_key
		and #$df
		bra @check_key
@check_esc:
		jsr ser_getcp
		bcc @none
		cmp #'['
		bne @none
		jsr ser_getcp
		bcc @none
		cmp #'A'
		beq @up_key
		cmp #'B'
		beq @down_key
		cmp #'C'
		beq @right_key
		cmp #'D'
		beq @left_key
@check_key:
		cmp #'I'
		beq @up_key
		cmp #'K'
		beq @down_key
		cmp #'L'
		beq @right_key
		cmp #'J'
		beq @left_key
		cmp #'P'
		beq @play_key
		cmp #'R'
		beq @redraw_key
		cmp #'Q'
		beq @quit_key
@none:
		lda #KEY_NONE
		rts
@up_key:
		lda #KEY_UP
		rts
@right_key:
		lda #KEY_RIGHT
		rts
@down_key:
		lda #KEY_DOWN
		rts
@left_key:
		lda #KEY_LEFT
		rts
@play_key:
		lda #KEY_PLAY
		rts
@redraw_key:
		lda #KEY_REDRAW
		rts
@quit_key:
		lda #KEY_QUIT
		rts

