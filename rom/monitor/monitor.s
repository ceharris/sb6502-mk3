		.include "ascii.h.s"
		.include "ansi.h.s"
		.include "jmptab.h.s"
		.include "registers.h.s"


		PARAGRAPH_SIZE = 16
		INPUT_BUF_SIZE = 64

		.segment "BSS"
input_buf:	
		.res INPUT_BUF_SIZE
input_buf_end:

		.segment "RODATA"
id_message:
		ansi_home
		ansi_erase_display
		.byte "SB6502 Mk3 Monitor", LF, LF
		.byte BEL
		.byte NUL
ihex_prompt: 	
		.byte "<Ctrl-C to stop>", LF, NUL
syntax_msg:
		.byte "syntax error", LF, BEL, NUL
checksum_msg:
		.byte "bad checksum", LF, BEL, NUL

		.segment "CODE"
		.word $CE5B
		.byte 0
		.word monitor_cold

monitor_cold:
		; print startup message to console
		ldiw0 id_message
		jsr J_CPUTS

		ldiw1 0

command:	
		jsr show_prompt	
		ldib0 INPUT_BUF_SIZE
		ldiw0 input_buf
		jsr J_CGETS
		pha			; preserve input terminator
		lda #LF		
		jsr J_CPUTC		; start a new line
		pla			; recover input terminator
		cmp #CTRL_C		; did input end with Ctrl-C?
		beq command		; yep... go back to the prompt

		lda b0			; get input length
		beq command		; zero... go back to the prompt

		; handle the input
		ldy #0			; start at beginning of string
		jsr range_arg
		bcs @error
		sta b0			; save arg count
		cmp #0			; no args?
		bne @match_command
		tw2w1			; if no args, use current in w2
@match_command:
		lda (w0),y		; get terminating char
		beq @peek
		cmp #':'
		beq @poke
		cmp #'*'
		beq @fill
		and #$df		; convert to upper case
		cmp #'H'
		beq @ihex
		cmp #'I'
		beq @ijump
		cmp #'J'
		beq @jump
		cmp #'K'
		beq @call
@error:
		lda #BEL
		jsr J_CPUTC
		jmp command

@peek:
		lda b0
		dec a			; A = arg count - 1
		bne @peek_two_args
		lda w1
		sta w2
		lda w1+1
		inc a
		sta w2+1
@peek_two_args:
		jsr hex_peek
		jmp command
@poke:
		iny			; skip delimiter
		jsr hex_poke		; poke hex bytes at addr w1
		jmp command

@fill:
		lda b0
		dec a			; A = arg count - 1
		beq @error		; must have two args
		jsr fill_range
		jmp command

@ihex:
		jsr ihex_load
		jmp command

@call:
		lda #>(command-1)
		pha
		lda #<(command-1)
		pha
		bra @jump
@ijump:
		; transfer vector address to w2
		tw1w2
		ldy #0

		; fetch the address stored in the vector into w1
		lda (w2),y
		sta w1
		iny
		lda (w2),y
		sta w1+1
@jump:
		jmp (w1)


;-----------------------------------------------------------------------
; show_prompt
; Print the command prompt.
;
	.proc show_prompt
		tw1w2
		lda w2+1
		jsr phex8
		lda w2
		jsr phex8
		lda #'>'
		jsr J_CPUTC
		lda #SPC
		jsr J_CPUTC
		rts
	.endproc


;-----------------------------------------------------------------------
; range_arg
; Get the address range args for a command.
;
	.proc range_arg
		jsr address_arg
		bcs @parse_range
		lda #0			; range has no args
		clc			; no error
		rts
@parse_range:
		lda b0
		sta w1
		lda b1
		sta w1+1
		lda (w0),y		; A = terminating char
		beq @check_range_type
		jsr is_hex
		bcc @check_range_type
		; carry set signals range error
		rts
			
@check_range_type:
		cmp #'-'		; is it 'start-end'?
		beq @range_start_end
		cmp #'+'		; is it 'start+length'?
		beq @range_start_length
		lda #1			; range has one arg
		clc			; no error
		rts
@range_start_end:
		iny			; skip delimiter
		jsr address_arg
		lda b0
		sta w2
		lda b1
		sta w2+1
		bra @two_args
@range_start_length:
		iny			; skip delimiter
		jsr address_arg
		; add length to start address to get end address
		clc
		lda b0
		adc w1
		sta w2
		lda b1
		adc w1+1
		sta w2+1
@two_args:
		lda #2			; range has two args
		clc			; no error
		rts

	.endproc

;-----------------------------------------------------------------------
; address_arg:
; Get the address range args for a command.
;
	.proc address_arg
		; assume MSB will be zero
		lda #0
		sta b0
		sta b1
		lda (w0),y		; A = first character
		jsr is_hex
		bcs @parse_address
		rts
@parse_address:
		; convert first byte of address
		jsr hex2bin
		lda (w0),y		; A = terminating character
		jsr is_hex
		bcc @done
		lda b0
		sta b1
		jsr hex2bin
@done:
		sec
		rts
	.endproc


;-----------------------------------------------------------------------
; fill_range:
; Fills a range of memory using the value stored in the first byte of
; the range.
; 
; On entry:
;	w1 = start of range
; 	w2 = end of range
;
; On return:
;	A, w0 clobbered
;
	.proc fill_range
		tw1w0			;put starting address in w0
		ldy #0
fill_again:
		; are we done?
		phw0
		sec
		sbcw2
		plw0
		bcc @fill_one
		rts
@fill_one:
		lda (w0),y		; get the byte to use for fill
		iny
		sta (w0),y		; fill a byte
		dey
		incw0			; next address
		bra fill_again
	.endproc


;-----------------------------------------------------------------------
; hex_peek:
; Produces a hex dump on the console for a range of memory addresses.
;
; On entry:
; 	w1 = starting address (inclusive)
;	w2 = ending address (exclusive)
;
; On return:
;	w0, b0 clobbered
; 	A, X, Y clobbered
;
	.proc hex_peek

		; put the starting address into w0
		tw1w0

		; truncate starting address to nearest paragraph
		lda w0
		and #256 - PARAGRAPH_SIZE
		sta w0
		
		; We'll use the post-indexed indirect address mode with a
		; constant offset, since it's the only indirect addressing
		; mode available for load/store
		ldy #0

		; The output is organized as 16-byte paragraphs, each preceded
		; by the paragraph's memory address in hexadecimal
@put_paragraph:
		lda w0+1		; MSB of current address
		jsr phex8		; output as hex
		lda w0			; LSB of current address
		jsr phex8		; output as hex
		
		; output colon delimiter
		lda #':'			
		jsr J_CPUTC			

		phw0			; preserve current address on stack
		ldx #PARAGRAPH_SIZE	; paragraph byte counter

@put_next_hex:
		; precede each byte with a space
		lda #SPC			
		jsr J_CPUTC	

		; do we need to skip this byte?
		jsr hex_check_skip
		bcc @show_hex
		
		; skip current byte
		lda #SPC
		jsr J_CPUTC
		jsr J_CPUTC
		bra @next_hex

		; output this byte
@show_hex:
		lda (w0),y
		; FIXME -- if w0 addresses a I/O device, fetching more than once may have
		; undesirable side effects (e.g. popping the stack on the 
		; AM9511). We SHOULD save the bytes of this paragraph in RAM and revisit
		; them from RAM when we print the ASCII equiv
		jsr phex8
@next_hex:
		jsr hex_next
		bcc @put_next_hex

		; output two spaces before ASCII representation
		lda #SPC
		jsr J_CPUTC
		jsr J_CPUTC

		plw0			; recover current address
		ldx #PARAGRAPH_SIZE	; paragraph byte counter

@put_next_asc:
		; do we need to skip this byte?
		jsr hex_check_skip
		bcc @show_asc

		; skip this byte
		lda #SPC
		jsr J_CPUTC
		bra @next_asc

		; output this byte
@show_asc:
		; FIXME -- if w0 addresses a I/O device, fetching more than once may have
		; undesirable side effects (e.g. popping the stack on the 
		; AM9511). We SHOULD save the bytes of this paragraph in RAM and revisit
		; them from RAM when we print the ASCII equiv
		lda (w0),y
		jsr pasc8
@next_asc:
		jsr hex_next
		bcc @put_next_asc
		lda #LF
		jsr J_CPUTC

		; are we done?
		phw0
		sec
		sbcw2
		plw0
		bcc @check_break
		rts

@check_break:
		; was Ctrl-C pressed?
		jsr J_CGETC
		bcc @next_paragraph
		cmp #CTRL_C
		bne @next_paragraph
		rts
@next_paragraph:
		jmp @put_paragraph
.endproc


;-----------------------------------------------------------------------
; hex_check_skip:
; Checks whether current is in the interval [start, end).
;
; On entry:
;	w0 = current address
;	w1 = start address
;	w2 = end address
;
; On return:
;	carry clear if and only if current in [start, end)
;
	.proc hex_check_skip
		phw0			; preserve w0
		sec
		sbcw1			; subtract starting addres
		plw0			; recover w0
		bcs @check_end		; no borrow means start <= current
		sec			; set carry to indicate skip
		rts
@check_end:	
		phw0			; preserve w0	
		sec
		sbcw2			; subtract ending address
		plw0			; recover w0
		; carry set if current >= end
		rts				
	.endproc


;-----------------------------------------------------------------------
;
	.proc hex_next
		incw0			; increment current address
		dex			; decrement byte counter
		bne @check_separator
		sec
		rts			; return with carry set

@check_separator:
		txa			; A = number of bytes remaining

		; are we halfway through?
		cmp #PARAGRAPH_SIZE >> 1
		bne @not_paragraph_end	; nope
		
		; output extra space to separate paragraph 2 groups of 8
		lda #SPC			
		jsr J_CPUTC

@not_paragraph_end:
		clc
		rts
	.endproc



	.proc hex_poke
		phx
		tya
		sta b2			; b2 = input offset
		ldy #0
		sty b3			; b3 = poke offset
		ldx #0			; byte counter
@poke_next:
		lda b2			; fetch input offset
		tay			; Y = input offset
@skip_space:
		lda (w0),y
		beq @done
		jsr is_hex
		bcs @poke_byte
		iny
		cmp #SPC
		beq @skip_space
		cmp #TAB
		beq @skip_space
		bcc @done
@poke_byte:		
		phx
		jsr hex2bin
		plx
		sty b2			; store input offset
		lda b3			; fetch poke offset
		tay			; Y = poke offset
		lda b0			; fetch input byte
		sta (w1),y		; poke input byte
		iny			; ++ poke offset
		sty b3			; store poke offset
		dex
		bne @poke_next
@done:
		plx
		rts
	.endproc


;-----------------------------------------------------------------------
; ihex_load:
; Loads a sequence of Intel Hex records from standard input.
;
;
	.proc ihex_load
		ldiw0 ihex_prompt
		jsr J_CPUTS

		ldib0 INPUT_BUF_SIZE
		ldiw0 input_buf
@next_rec:
		ldy #0
		jsr J_CGETS
		pha			; preserve input terminator
		lda #LF		
		jsr J_CPUTC		; output newline
		pla
		cmp #CTRL_C		; terminated by Ctrl-C?
		bne @find_rec
		rts
@find_rec:
		lda (w0),y		; get next input char
		beq @next_rec		; next record on null terminator
		iny

		cmp #':'		; start of record?
		bne @find_rec

		lda #0
		sta b2			; b2 = initial checksum

		; read record length
		jsr @read_byte
		bcc @syntax_error
		lda b0
		sta b1			; b1 = record length
		
		; read address MSB
		jsr @read_byte
		bcc @syntax_error
		lda b0
		sta w1+1		; w1 MSB = address MSB

		; read address LSB
		jsr @read_byte
		bcc @syntax_error
		lda b0
		sta w1			; w1 LSB = address LSB

		; read record type
		jsr @read_byte
		bcc @syntax_error
		lda b0
		beq @data_rec		; go if type 0 (data record)
		cmp #1
		bne @syntax_error	; go if not type 1 (EOF record)

		; end of file record
@eof_rec:
		jsr @read_byte		; read checksum
		lda b2			; A = record checksum
		bne @checksum_error
		rts
		
@data_rec:
		lda b1			; A = record length
		beq @data_rec_end
		dec b1
		jsr @read_byte
		bcc @syntax_error
		phy
		ldy #0
		lda b0
		sta (w1),y		; store input byte
		ply
		; increment w1
		inc w1
		bne @data_rec
		inc w1+1
		bra @data_rec
@data_rec_end:
		jsr @read_byte		; read checksum
		bcc @syntax_error
		lda b2			; A = record checksum
		bne @checksum_error
		jmp @next_rec

@checksum_error:
		ldiw0 checksum_msg
		bra @error
@syntax_error:
		ldiw0 syntax_msg
@error:
		jsr J_CPUTS
		rts

@read_byte:
		jsr hex2bin
		txa			; A = number of digits
		lsr			; check for even number of digits
		bcc @update_checksum
		clc
		rts
@update_checksum:
		lda b2			; A = checksum
		clc
		adc b0			; update checksum
		sta b2			; store new checksum 
		sec			; carry set indicates success
		rts

	.endproc


;-----------------------------------------------------------------------
; hex2bin:
; Converts a string to an 8-bit binary value. Conversion stops after
; at most two hexadecimal digits have been converted or when a non-
; hexadecimal character is encountered in the input.
;
; On entry:
;	w0 points to the null-terminated input string
;	Y is the current offset into the input string
; 
; On return:
;	A, b0 = converted value
;	Y is the new offset into the input string
;	X is the number of digits read
;
	.proc	hex2bin
		phy
		ldx #0			; digit counter
@check_next:
		lda (w0),y
		inx
		iny
		jsr is_hex
		bcs @check_next

		ply			; recover input offset
		lda #0			; default result
		sta b0			; store result
		dex			; X = number of hex digits
		beq @done		; done if no digits found

		txa			; A = digit count
		lsr			; set carry if odd digit count
		bcs @odd		; go if odd count
		; convert upper nibble
		lda (w0),y		; fetch hex digit
		iny			; ++ input offset
		jsr htob4		; convert digit to binary
		; shift to upper nibble
		asl
		asl
		asl
		asl
		and #$f0		; zero lower nibble
		sta b0			; save it
		;convert lower nibble
@odd:
		lda (w0),Y		; fetch hex digit
		iny			; ++ input offset
		jsr htob4		; convert digit to binary
		ora b0			; merge in upper nibble
		sta b0
@done:
		rts

	.endproc


;-----------------------------------------------------------------------
; htob4: 
; Converts a hexadecimal digit to a 4-bit binary value.
;
; On entry:
;	A = ASCII character in ['0'..'9'] | ['A'..'F'] | ['a'..'b']
;
; On return:
;	A = converted value in range [0..15]
;
	.proc htob4
		cmp #'9'+1
		bcc @num_digit
		and #$df		; convert to upper case
		sec
		sbc #7			; A now in [$3A..$3F]
@num_digit:
		sec
		sbc #'0'		; A now in [0..15]
		rts
	.endproc


;-----------------------------------------------------------------------
; is_hex:
; Tests whether the character in A is an ASCII hexadecimal digit
;
; On entry:
;	A = character to test
;
; On return:
;	carry set if and only if A contains an ASCII hexadecimal digit
;
	.proc is_hex
		cmp #'0'
		bcc @done
		cmp #'9'+1
		bcc @hex
		cmp #'A'
		bcc @done
		cmp #'F'+1
		bcc @hex
		cmp #'a'
		bcc @done
		cmp #'f'+1
		bcc @hex
@done:
		clc
		rts
@hex:
		sec
		rts

	.endproc


;-----------------------------------------------------------------------
; phex8:
; Displays an 8-bit value as two hexadecimal digits
;
; On entry:
;	A contains the value to be displayed
;
	.proc phex8
		pha			; preserve input value
		; shift upper nibble to lower nibble
		lsr
		lsr
		lsr
		lsr
		jsr phex4		; display upper nibble in hex
		pla			; recover input value
		jsr phex4		; display lower nibble in hex
		rts	
	.endproc


;-----------------------------------------------------------------------
; phex4:
; Displays a 4-bit value as a hexadecimal digit.
;
; On entry:
; 	Lower 4-bits of A contain the value to be displayed
;
	.proc phex4
		and #$f			; isolate lower nibble
		clc	
		adc #'0'		; A now in ['0'..)
		cmp #'9' + 1
		bcc @no_adjust		; go if A in ['0'..'9']
		clc
		adc #7 + $20		; A now in ['a'..'f']
@no_adjust:
		jsr J_CPUTC		; display hex digit
		rts
	.endproc


;-----------------------------------------------------------------------
; pasc8:
; Displays the ASCII representation of an 8-bit value.
;
	.proc pasc8
		; is it an ASCII control character [0..0x31]?
		cmp #SPC
		bcc @put_dot
		; is it in the range [0x7f..0x80]?
		cmp #DEL
		bcs @put_dot
		; it's an ordinary printable ASCII character
		jsr J_CPUTC
		rts
@put_dot:
		; display a dot instead of the actual value
		lda #'.'
		jsr J_CPUTC
		rts
	.endproc
