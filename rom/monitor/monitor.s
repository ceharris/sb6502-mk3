		.include "ascii.h.s"
		.include "ansi.h.s"
		.include "hex.h.s"
		.include "prog.h.s"
		.include "registers.h.s"
		.include "stdio.h.s"


		PARAGRAPH_SIZE = 16
		INPUT_BUF_SIZE = 64

		.segment "MAGIC"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $80
		.word monitor

		.segment "BSS"
input_buf:	
		.res INPUT_BUF_SIZE
input_buf_end:

		.segment "CODE"
monitor:
		jsr cinit
		cli
		ldiw1 0
command:	
		jsr show_prompt	
		ldiw0 STDIO_BUF_ADDR
		jsr cgets
		pha			; preserve input terminator
		lda #LF		
		jsr cputc		; start a new line
		pla			; recover input terminator
		cmp #CTRL_C		; did input end with Ctrl-C?
		beq command		; yep... go back to the prompt

		lda STDIO_B0		; get input length
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
		lda (STDIO_W0),y	; get terminating char
		beq @peek
		cmp #':'
		beq @poke
		cmp #'*'
		beq @fill
		and #$df		; convert to upper case
		cmp #'I'
		beq @ijump
		cmp #'J'
		beq @jump
		cmp #'K'
		beq @call
		cmp #'~'
		jmp bye
@error:
		lda #BEL
		jsr cputc
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
		.import peek
		jsr peek
		jmp command
@poke:
		.global poke
		iny			; skip delimiter
		jsr poke		; poke hex bytes at addr w1
		jmp command

		.global fill
@fill:
		lda b0
		dec a			; A = arg count - 1
		beq @error		; must have two args
		jsr fill
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
		jsr cputc
		lda #SPC
		jsr cputc
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
		lda (STDIO_W0),y	; A = terminating char
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
		lda (STDIO_W0),y	; A = first character
		jsr is_hex
		bcs @parse_address
		rts
@parse_address:
		; convert first byte of address
		jsr hex2bin
		lda (STDIO_W0),y	; A = terminating character
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
		.global hex2bin
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
;	A = ASCII character in ['0'..'9'] | ['A'..'F'] | ['a'..'f']
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
		.global is_hex
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


CONF_REG := $FFD8
MMU_SLOT0 := $FFC0
CONF_MMUE := $80
IPL_VECTOR := $F000
BYE_VECTOR := $F0

bye_fn:
		; disable MMU
                lda CONF_REG
                and #<~CONF_MMUE
                sta CONF_REG
		; jump back to the IPL program
                jmp IPL_VECTOR

BYE_FN_LENGTH := *-bye_fn

bye:
		; quiesce the system
                sei
                jsr acia_shutdown
		; put bank 0 in slot zero since we will disable MMU
		stz MMU_SLOT0
		; copy bye_fn into the zero page
                ldx #BYE_FN_LENGTH
                ldy #0
@copy:
                lda bye_fn,y
                sta BYE_VECTOR,y
                iny
                dex
                bne @copy
                jmp BYE_VECTOR

