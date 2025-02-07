
		.include "model.h.s"
		.include "keys.h.s"
		.segment "CODE"

		GRID_PAGES = GRID_CELLS / 256
		GRID_REMAINDER = GRID_CELLS - 256*GRID_PAGES

;-----------------------------------------------------------------------
; model_init:
; Configures the initial state for the game.
;
model_init:
		jsr _init_grid
		lda #0
		sta game_flags
		sta score
		sta score+1
		lda #GAME_START_X
		sta snake_head_x
		sta snake_tail_x
		lda #GAME_START_Y
		sta snake_head_y
		sta snake_tail_y
		lda #8
		sta grow_count
		rts


;-----------------------------------------------------------------------
; next_state:
; Resolve the next state of the game model.
;
model_next:
		jsr _update_head
		lda game_flags
		and #(GF_AXIS_VERTICAL | GF_OP_DECREMENT)
		ora #$80
		sta (snake_head_addr)
		lda #SNAKE_HEAD_CELL
		sta (next_head_addr)
		lda grow_count
		bne @grow
		jsr _update_tail
		bra @finish
@grow:
		dea
		sta grow_count
@finish:		
		lda next_head_x
		sta snake_head_x
		lda next_head_y
		sta snake_head_y
		lda next_head_addr
		sta snake_head_addr
		lda next_head_addr+1
		sta snake_head_addr+1

		lda #1
		jsr _incr_score
		rts


;-----------------------------------------------------------------------
; model_key_event:
; Updates the model according to a received key event.
; 
; On entry:
;	A = key code
;
model_key_event:
		cmp #KEY_UP
		beq @move_up
		cmp #KEY_RIGHT
		beq @move_right
		cmp #KEY_DOWN
		beq @move_down
		cmp #KEY_LEFT
		beq @move_left
		rts
@move_up:
		lda game_flags
		ora #<(GF_AXIS_VERTICAL | GF_OP_DECREMENT)
		sta game_flags
		rts
@move_right:
		lda game_flags
		and #<~(GF_AXIS_VERTICAL | GF_OP_DECREMENT)
		sta game_flags
		rts
@move_down:
		lda game_flags
		and #<~GF_OP_DECREMENT
		ora #<GF_AXIS_VERTICAL
		sta game_flags
		rts
@move_left:
		lda game_flags
		and #<~GF_AXIS_VERTICAL
		ora #<GF_OP_DECREMENT
		sta game_flags
		rts

_init_grid:
		lda #<game_grid
		sta W
		lda #>game_grid
		sta W+1
		lda #EMPTY_CELL
		ldx #GRID_PAGES
		ldy #0
@page_loop:		
		sta (W),y
		iny
		bne @page_loop
		inc W+1			; next page
		dex
		bne @page_loop
		ldx #GRID_REMAINDER
@remainder_loop:
		sta (W),y
		iny
		dex
		bne @remainder_loop
		rts


;-----------------------------------------------------------------------
; _update_head:
; Update the head of the snake.
; Coordinates of the new head cell are determined using the current
; head coordinates and the bit-mapped game flags.
;
; On entry:
;	snake_head_x, snake_head_y are the current head coordinates
; 
; On return:
;	next_head_x, next_head_y are the new new head coordinates
;	next_head_addr is the grid offset of the new head cell
;	snake_head_x, snake_head_y is unchanged
;	snake_head_addr is unchanged
;	grid content is unchanged
;
_update_head:
		ldx snake_head_x
		ldy snake_head_y
		; use game_flags to determine next head cell
		lda game_flags		; get flags
		lsr			; set carry to vertical/horizontal flag
		bcs @vertical_next	; go if next is on vertical axis
		lsr			; set carry to decrement/increment flag
		bcs @dec_horizontal	; go if decrementing
		jsr _incr_horizontal	; increment X coordinate with wrap
		bra @next_head_addr
@dec_horizontal:
		jsr _decr_horizontal	; decrement X coordinate with wrap
		bra @next_head_addr
@vertical_next:
		lsr			; set carry to decrement/increment flag
		bcs @dec_vertical	; go if decrementing
		jsr _incr_vertical	; increment Y coordinate with wrap
		bra @next_head_addr
@dec_vertical:
		jsr _decr_vertical	; decrement Y coordinate with wrap

@next_head_addr:
		stx next_head_x
		sty next_head_y

		; Y = 2*next_head_y to find the offset within _y_offset_addr table
		tya
		asl
		tay
		
		; fetch address of column 0 in row Y and store in next_head_addr
		lda _y_offset_addr,y
		sta next_head_addr
		lda _y_offset_addr+1,y
		sta next_head_addr+1

		; add the column to get the address of the cell and store in next_head_addr
		txa			; A = next_head_x
		clc
		adc next_head_addr
		sta next_head_addr
		bcc @no_carry
		inc next_head_addr+1
@no_carry:
		rts


;-----------------------------------------------------------------------
; _update_tail:
; Update the tail of the snake.
; Coordinates of the new tail cell are determined using the current
; tail cell coordinates and the bit-mapped flags in the current cell
; itself.
;
; On entry:
;	(snake_tail_x, snake_tail_y) are the current tail coordinates
;
; On return:
;	(prev_tail_x, prev_tail_y) are the tail coordinates on entry
;	(snake_tail_x, snake_tail_y) are the new tail coordinates
;	(snake_tail_addr) is the grid offset of the new tail cell
;	previous cell is empty
;
_update_tail:
		; save snake tail coordinates
		lda snake_tail_x
		sta prev_tail_x
		tax			; X = current tail X
		lda snake_tail_y
		sta prev_tail_y
		tay			; Y = current tail Y

		; use tail cell content to determine next tail cell
		lda (snake_tail_addr)	; get contents of tail cell
		lsr			
		bcs @vertical_next	; go if next is on vertical axis
		lsr			; go if decrementing
		bcs @dec_horizontal
		jsr _incr_horizontal	; increment X coordinate with wrap
		bra @next_tail_addr
@dec_horizontal:
		jsr _decr_horizontal	; decrement X coordinate with wrap
		bra @next_tail_addr
@vertical_next:
		lsr			; set carry if decrementing
		bcs @dec_vertical
		jsr _incr_vertical	; increment Y coordinate with wrap
		bra @next_tail_addr
@dec_vertical:
		jsr _decr_vertical	; decrement Y coordinate with wrap

@next_tail_addr:
		; save new tail XY
		stx snake_tail_x		
		sty snake_tail_y

		; empty the current tail cell
		lda #EMPTY_CELL
		sta (snake_tail_addr)	

		; Y = 2*snake_tail_y
		tya
		asl
		tay
		
		; fetch address of column 0 in the row and store in snake_tail_addr
		lda _y_offset_addr,y
		sta snake_tail_addr
		lda _y_offset_addr+1,y
		sta snake_tail_addr+1

		; add the column to get the address of the cell and store in snake_tail_addr
		txa			; A = snake_tail_x
		clc
		adc snake_tail_addr
		sta snake_tail_addr
		bcc @no_carry
		inc snake_tail_addr+1
@no_carry:
		rts


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
_incr_horizontal:
		inx
		cpx #GRID_COLUMNS
		bcc @done
		ldx #0
@done:
		rts	


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
_decr_horizontal:
		dex
		bmi @wrap
		rts
@wrap:
		ldx #GRID_COLUMNS-1
		rts	


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
_incr_vertical:
		iny
		cpy #GRID_ROWS
		bcc @done
		ldy #0
@done:
		rts	


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
_decr_vertical:
		dey
		bmi @wrap
		rts
@wrap:
		ldy #GRID_ROWS-1
		rts	


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
;	(game_flags) = (game_flags)' | GF_SCORE_CHANGE
;	A = (game_flags)' | GF_SCORE_CHANGE
;
_incr_score:
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
;	(game_flags) = (game_flags)' | GF_SCORE_CHANGE
;	A = (game_flags)' | GF_SCORE_CHANGE
;	B clobbered
;
_decr_score:
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


;-----------------------------------------------------------------------
; _set_score_flag:
; Sets the change flag for the score so that the UI representation will 
; be updated at the next refresh.
;
; On return:
;	A = (game_flags) | GF_SCORE_CHANGE
;
_set_score_flag:
		lda game_flags
		ora #GF_SCORE_CHANGE
		sta game_flags
		rts



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
