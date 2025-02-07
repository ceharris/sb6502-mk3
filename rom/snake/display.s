
		.include "ascii.h.s"
		.include "display.h.s"
		.include "serial.h.s"
		.include "state.h.s"


	.macro UI_PUT_ANSI_CSI
		lda #ESC
		jsr ser_putc
		lda #'['
		jsr ser_putc
	.endmacro

	.macro UI_PUT_ANSI_CUP
		lda #'H'
		jsr ser_putc
	.endmacro

	.macro UI_PUT_ANSI_ED p
		lda #p
		jsr ser_putc
		lda #'J'
		jsr ser_putc
	.endmacro

	.macro UI_PUT_SNAKE_SEGMENT
		lda #$E2
		jsr ser_putc
		lda #$96
		jsr ser_putc
		lda #$88
		jsr ser_putc
		lda #$E2
		jsr ser_putc
		lda #$96
		jsr ser_putc
		lda #$88
		jsr ser_putc
	.endmacro

	.macro UI_PUT_EMPTY_SEGMENT
		lda #' '
		jsr ser_putc
		lda #' '
		jsr ser_putc
	.endmacro

	.macro UI_HIDE_CURSOR
		UI_PUT_ANSI_CSI
		lda #'?'
		jsr ser_putc
		lda #'2'
		jsr ser_putc
		lda #'5'
		jsr ser_putc
		lda #'l'
		jsr ser_putc
	.endmacro

	.macro UI_SHOW_CURSOR
		UI_PUT_ANSI_CSI
		lda #'?'
		jsr ser_putc
		lda #'2'
		jsr ser_putc
		lda #'5'
		jsr ser_putc
		lda #'h'
		jsr ser_putc
	.endmacro

		.segment "CODE"

;-----------------------------------------------------------------------
; ui_clear:
;
	.proc ui_clear
		; clear display
		ldiw _clear_display
		jsr ser_puts
		
		; start the status line
		ldiw _status_line_pre
		jsr ser_puts

		; display empty status line
		lda #' '
		ldx #80
		jsr ser_putsc
		
		; display title label
		ldiw _title_cup
		jsr ser_puts
		ldiw _title_label
		jsr ser_putsw

		; display score label
		ldiw _score_label
		jsr ser_puts

		; finish the status line
		ldiw _status_line_post
		jsr ser_puts

		rts
	.endproc


ui_redraw:
		jsr ui_clear
		ldx #0
		ldy #0
		jsr ui_put_grid_cup
		ldiw game_grid
		ldy #GRID_ROWS
@next_row:
		ldx #GRID_COLUMNS
@next_column:
		lda (W)
		and #$80
		beq @snake_segment
		UI_PUT_SNAKE_SEGMENT
		bra @until_done
@snake_segment:
		UI_PUT_EMPTY_SEGMENT
@until_done:
		inc W
		bne @no_carry
		inc W+1
@no_carry:
		dex
		bne @next_column
		dey
		bne @next_row
		jsr ser_flush	
		rts


ui_update:
		lda grow_count
		bne @head
		ldx prev_tail_x
		ldy prev_tail_y
		jsr ui_put_empty_segment
@head:
		ldx snake_head_x
		ldy snake_head_y
		jsr ui_put_snake_segment

		lda game_flags
		and #GF_SCORE_CHANGE
		beq @done
		jsr ui_put_score
@done:
		jsr ser_flush
		rts

;-----------------------------------------------------------------------
; ui_put_snake_segment:
;
; On entry:
;	X = grid X coordinate
;	Y = grid Y coordinate
;
ui_put_snake_segment:
		jsr ui_put_grid_cup
		UI_PUT_SNAKE_SEGMENT
		rts


;-----------------------------------------------------------------------
; ui_put_empty_segment:
;
; On entry:
;	X = grid X coordinate
;	Y = grid Y coordinate
;
ui_put_empty_segment:
		jsr ui_put_grid_cup
		UI_PUT_EMPTY_SEGMENT
		rts


;-----------------------------------------------------------------------
; ui_put_grid_cup:
; Puts an ANSI CUP (cursor position) sequence representing a grid 
; coordinate pair into the serial output buffer.
;
; On entry:
;	X = grid X coordinate
;	Y = grid Y coordinate
;
ui_put_grid_cup:
		phx
		phy
		UI_PUT_ANSI_CSI
		
		; Y = 2*Y
		tya
		asl
		tay

		; put first digit of row
		lda grid_y_to_row,y
		jsr ser_putc

		; put second digit of row
		lda grid_y_to_row+1,y
		beq @put_sep		; go if only one digit
		jsr ser_putc
@put_sep:
		lda #';'
		jsr ser_putc

		; X = 2*X
		txa
		asl
		tax

		; put first digit of column
		lda grid_x_to_column,x
		jsr ser_putc

		; put second digit of column
		lda grid_x_to_column+1,x
		beq @put_cup		; go if only one digit
		jsr ser_putc
@put_cup:
		UI_PUT_ANSI_CUP
		ply
		plx
		rts

ui_put_score:
		ldiw _score_pre
		jsr ser_puts		
		lda score+1
		ldx score
		jsr _phex16
		ldiw _score_post
		jsr ser_puts
		rts

show_positions:
		ldiw _status_line_pre
		jsr ser_puts
		lda #SPC
		jsr ser_putc
		lda snake_head_x
		jsr _phex8
		lda #','
		jsr ser_putc
		lda snake_head_y
		jsr _phex8
		lda #SPC
		jsr ser_putc
		lda snake_head_addr+1
		ldx snake_head_addr
		jsr _phex16
		lda #SPC
		jsr ser_putc
		lda snake_tail_x
		jsr _phex8
		lda #','
		jsr ser_putc
		lda snake_tail_y
		jsr _phex8
		lda #SPC
		jsr ser_putc
		lda snake_tail_addr+1
		ldx snake_tail_addr
		jsr _phex16
		ldiw _status_line_post
		jsr ser_puts
		rts

		.byte ESC
;-----------------------------------------------------------------------
; _phex16:
; Prints a 16-bit value as four hexadecimal digits
;
; On entry:
;	AX contains the value to be printed
;
_phex16:
		pha
		jsr _phex8		; print the MSB
		txa
		jsr _phex8		; print the MSB
		pla
		rts


;-----------------------------------------------------------------------
; _phex8:
; Displays an 8-bit value as two hexadecimal digits
;
; On entry:
;	A contains the value to be displayed
;
_phex8:
		pha			; preserve input value
		; shift upper nibble to lower nibble
		lsr
		lsr
		lsr
		lsr
		jsr _phex4		; display upper nibble in hex
		pla			; recover input value
		jsr _phex4		; display lower nibble in hex
		rts	


;-----------------------------------------------------------------------
; _phex4:
; Displays a 4-bit value as a hexadecimal digit.
;
; On entry:
; 	Lower 4-bits of A contain the value to be displayed
;
_phex4:
		and #$f			; isolate lower nibble
		clc	
		adc #'0'		; A now in ['0'..)
		cmp #'9' + 1
		bcc @no_adjust		; go if A in ['0'..'9']
		clc
		adc #7			; A now in ['A'..'F']
@no_adjust:
		jsr ser_putc		; display hex digit
		rts


		.segment "RODATA"

;-----------------------------------------------------------------------
; grid_x_to_column:
; This table is used to lookup the ANSI terminal column number that
; corresponds to the X component of a grid coordinate pair. ANSI column
; numbers start a 1 and are represented using ASCII digits. 
;
; Every table entry contains two bytes. Column numbers less than 10 are
; represented as a single ASCII digit followed by ASCII NUL. The NUL 
; character must not be transmitted to the terminal when sending such
; column numbers.
; 
; The game grid consists of 40 x 24 cells, therefore there are 40 table
; entries. Each table entry represents two consecutive columns of the
; 80x25 terminal display.
;
grid_x_to_column:
		.byte "1",0
		.byte "3",0
		.byte "5",0
		.byte "7",0
		.byte "9",0
		.byte "11"
		.byte "13"
		.byte "15"
		.byte "17"
		.byte "19"
		.byte "21"
		.byte "23"
		.byte "25"
		.byte "27"
		.byte "29"
		.byte "31"
		.byte "33"
		.byte "35"
		.byte "37"
		.byte "39"
		.byte "41"
		.byte "43"
		.byte "45"
		.byte "47"
		.byte "49"
		.byte "51"
		.byte "53"
		.byte "55"
		.byte "57"
		.byte "59"
		.byte "61"
		.byte "63"
		.byte "65"
		.byte "67"
		.byte "69"
		.byte "71"
		.byte "73"
		.byte "75"
		.byte "77"
		.byte "79"

;-----------------------------------------------------------------------
; grid_y_to_row:
; This table is used to lookup the ANSI terminal row number that
; corresponds to the Y component of a grid coordinate pair. ANSI column
; numbers start a 1 and are represented using ASCII digits. 
;
; Every table entry contains two bytes. Row numbers less than 10 are
; represented as a single ASCII digit followed by ASCII NUL. The NUL 
; character must not be transmitted to the terminal when sending such
; row numbers.
;
; The game grid consists of 40 x 24 cells, therefore there are 24 table
; entries. Each table entry represents one row of the 80x25 terminal
; display.
;
grid_y_to_row:
		.byte "1",0
		.byte "2",0
		.byte "3",0
		.byte "4",0
		.byte "5",0
		.byte "6",0
		.byte "7",0
		.byte "8",0
		.byte "9",0
		.byte "10"
		.byte "11"
		.byte "12"
		.byte "13"
		.byte "14"
		.byte "15"
		.byte "16"
		.byte "17"
		.byte "18"
		.byte "19"
		.byte "20"
		.byte "21"
		.byte "22"
		.byte "23"
		.byte "24"

_clear_display:
		.byte ESC,"[?25l",ESC,"[H",ESC,"[J"
_status_line_pre:
		.byte ESC,"[25;1H",ESC,"[7m",0
_status_line_post:
_score_post:
		.byte ESC,"[0m",0
_title_cup:
		.byte ESC,"[25;34H",0
_title_label:
		.byte "SNAKE!",0
_game_over_cup:
		.byte ESC,"[25;32H",0
_game_over_label:
		.byte "GAME OVER",0
_score_label:
		.byte ESC,"[25;69HScore 0000",0
_score_pre:
		.byte ESC,"[25;75H",ESC,"[7m",0
