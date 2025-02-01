
		.include "model.h.s"

		.segment "CODE"


;-----------------------------------------------------------------------
; next_state:
; Resolve the next state of the game model.
;
	.proc next_state
		jsr _next_head_xy
		stx next_x
		sty next_y
		jsr _next_head_addr

	.endproc

;-----------------------------------------------------------------------
; _next_head_addr:
; Determine the cell address for the next position of the snake head
;
; On entry:
;	X, Y = grid coordinates of the next position of the snake head
;
; On return:
;	(next_addr) = address of the cell
;	Y = 2*Y'
;
	.proc _next_head_addr

		; Y = 2*Y
		tya
		asl
		tay
		
		; fetch address of column 0 in the row and store in next_addr
		lda _y_offset_addr,y
		sta next_addr
		lda _y_offset_addr+1,y
		sta next_addr+1

		; add the column to get the address of the cell and store in next_addr
		txa
		clc
		adc next_addr
		sta next_addr
		lda #0
		adc next_addr+1
		sta next_addr+1

		rts
	
	.endproc

;-----------------------------------------------------------------------
; _next_head_xy:
; Determine the next grid XY coordinate for the snake head.
;
; On return:
;	X, Y = next grid coordinate for the snake head
;
	.proc _next_head_xy
		ldx snake_head_x
		ldy snake_head_y
		lda game_flags
		lsr
		bcs @axis_vertical
		lsr
		bcs _decr_horizontal
		bcc _incr_horizontal
@axis_vertical:
		lsr
		bcs _decr_vertical
		bcc _incr_vertical
	.endproc


;-----------------------------------------------------------------------
; _incr_horizontal:
; Increments a horizontal grid coordinate in the X register, modulo
; the number of grid columns.
;
; On entry:
;	X = grid column
; On return:
;	X = (X' + 1) mod GRID_COLUMNS
;
	.proc _incr_horizontal
		inx
		cpx #GRID_COLUMNS
		bcc @done
		ldx #0
@done:
		rts	
	.endproc


;-----------------------------------------------------------------------
; _decr_horizontal:
; Decrements a horizontal grid coordinate in the X register, modulo
; the number of grid columns.
;
; On entry:
;	X = grid column
; On return:
;	X = (X' - 1) mod GRID_COLUMNS
;
	.proc _decr_horizontal
		dex
		bmi @wrap
		rts
@wrap:
		ldx #GRID_COLUMNS-1
		rts	
	.endproc


;-----------------------------------------------------------------------
; _incr_vertical:
; Increments a vertical grid coordinate in the Y register, modulo
; the number of grid rows.
;
; On entry:
;	Y = grid row
; On return:
;	Y = (Y' + 1) mod GRID_ROWS
;
	.proc _incr_vertical
		iny
		cpy #GRID_ROWS
		bcc @done
		ldy #0
@done:
		rts	
	.endproc


;-----------------------------------------------------------------------
; _decr_vertical:
; Decrements a vertical grid coordinate in the Y register, modulo
; the number of grid rows.
;
; On entry:
;	Y = grid row
; On return:
;	Y = (Y' - 1) mod GRID_ROWS
;
	.proc _decr_vertical
		dey
		bmi @wrap
		rts
@wrap:
		ldy #GRID_ROWS-1
		rts	
	.endproc


;-----------------------------------------------------------------------
; _incr_score:
; Increment the player's score and set the score's dirty flag so that the 
; UI representation is updated at the next refresh.
;
; On entry:
; 	A = amount by which the score should be increased
;
; On return:
;	(score) = (score)' + A'
;	(game_flags) = (game_flags)' | GF_SCORE_DIRTY
;	A = (game_flags)' | GF_SCORE_DIRTY
;
	.proc _incr_score
		; add A to (score) using BCD
		sed
		clc
		adc score			; increment LSB
		sta score
		lda #0
		adc score+1			; propgate carry to MSB
		sta score+1
		cld
		bra _set_score_flag
	.endproc


;-----------------------------------------------------------------------
; _decr_score:
; Decrement the player's score and set the score's dirty flag so that the 
; UI representation is updated at the next refresh. If the resulting 
; score would be negative, it is instead set to zero.
;
; On entry:
; 	A = amount by which the score should be decreased
;
; On return:
;	(score) = (score)' - A'
;	(game_flags) = (game_flags)' | GF_SCORE_DIRTY
;	A = (game_flags)' | GF_SCORE_DIRTY
;	B clobbered
;
	.proc _decr_score
		; subtract A from (score) using BCD
		sta B
		sed
		sec
		lda score
		sbc B
		sta score
		stz B
		lda score+1
		sbc B
		sta score+1
		cld
		bcs _set_score_flag
		; result would be negative; reset score to zero
		stz score
		stz score+1
		bra _set_score_flag
	.endproc


;-----------------------------------------------------------------------
; _set_score_flag:
; Sets the dirty flag for the score so that the UI representation will 
; be updated at the next refresh.
;
; On return:
;	A = (game_flags) | GF_SCORE_DIRTY
;
	.proc _set_score_flag
		lda game_flags
		ora #GF_SCORE_DIRTY
		sta game_flags
		rts
	.endproc


		.segment "RODATA"

;-----------------------------------------------------------------------
; _y_offset_addr:
; A table of game grid offsets for each row in the grid.
; Given a vertical grid coordinate in the range 0..GRID_ROWS (23), the
; corresponding table entry gives the address of the cell that corresponds
; to X=0 on that row.
;
_y_offset_addr:
		.word game_grid + 0*GRID_COLUMNS
		.word game_grid + 1*GRID_COLUMNS
		.word game_grid + 2*GRID_COLUMNS
		.word game_grid + 3*GRID_COLUMNS
		.word game_grid + 4*GRID_COLUMNS
		.word game_grid + 5*GRID_COLUMNS
		.word game_grid + 6*GRID_COLUMNS
		.word game_grid + 7*GRID_COLUMNS
		.word game_grid + 8*GRID_COLUMNS
		.word game_grid + 9*GRID_COLUMNS
		.word game_grid + 10*GRID_COLUMNS
		.word game_grid + 11*GRID_COLUMNS
		.word game_grid + 12*GRID_COLUMNS
		.word game_grid + 13*GRID_COLUMNS
		.word game_grid + 14*GRID_COLUMNS
		.word game_grid + 15*GRID_COLUMNS
		.word game_grid + 16*GRID_COLUMNS
		.word game_grid + 17*GRID_COLUMNS
		.word game_grid + 18*GRID_COLUMNS
		.word game_grid + 19*GRID_COLUMNS
		.word game_grid + 20*GRID_COLUMNS
		.word game_grid + 21*GRID_COLUMNS
		.word game_grid + 22*GRID_COLUMNS
		.word game_grid + 23*GRID_COLUMNS
