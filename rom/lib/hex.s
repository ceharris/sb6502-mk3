		.include "hex.h.s"
		.include "stdio.h.s"


;-----------------------------------------------------------------------
; hextok:
; Tests the stdio buffer at the specified offset to determine whether
; it contains a hexadecimal string.
;
; On entry:
;	STDIO_W0 points to a null-terminated input string to be tested
;	Y is the offset within the buffer that is be tested
; 
; On return:
;	STDIO_B0 and A = number of hexadecimal digits found at the start 
;	    of the input string
;	Z flag set if no hexadecimal digits found
;	Y = Y' + number of hexadecimal digits found
;
hextok:
		phx
		ldx #0			; digit counter
@check_next:
		lda (STDIO_W0),y	; fetch next input character
		inx			; digit count++
		iny			; input pointer++
	
		; is it a digit '0'..'9'?
		cmp #'0'
		bcc @done
		cmp #'9'+1
		bcc @check_next
		; is it a letter 'A'..'F'?
		cmp #'A'
		bcc @done
		cmp #'F'+1
		bcc @check_next
		; is it a letter 'a'..'f'?
		cmp #'a'
		bcc @done
		cmp #'f'+1
		bcc @check_next
@done:
		dex			; X = number of hexadecimal digits
		dey			; Y -> first char that isn't hex
		txa			; A = number of hexadecimal digits
		sta STDIO_B0		; B0 = number of hexadecimal digits
		plx
		lda STDIO_B0		; set Z flag if no digits
		rts

;-----------------------------------------------------------------------
; ihex16:
; Converts a hexadecimal digit string of 1 to 4 digits into a 16-bit
; binary value.
;
; On entry:
;	A is the number of hexadecimal digits to convert (1..2)
;
; On return: 
;	AX = 16 bit value of the converted digits
;	Y = Y' + the number of converted digits
;	converted digits clobbered
;
ihex16:
	sta STDIO_B0		; save digit count
	cmp #5			; if more than 4 digits
	bcs @is_even		; ... consume just the first four
	lsr			; set carry if odd number of digits
	bcc @is_even
	jsr _ihex4		; convert the first digit
	bra @is_odd
@is_even:
	jsr _ihex8		; convert first two digits
@is_odd:
	tax			; X = converted value
	lda STDIO_B0		; A = number of digits
	cmp #3
	lda #0			; A = MSB of zero
	bcc @lsb_only		; go if less than three digits
	jsr _ihex8		; there must be two more digits
	phx			; save MSB
	tax			; X = LSB
	pla			; A = MSB
@lsb_only:
	rts


;-----------------------------------------------------------------------
; ihex8:
; Converts a hexadecimal digit string of 1 or 2 digits into an 8-bit
; binary value.
;
; On entry:
;	A is the number of hexadecimal digits to convert (1..2)
;
; On return: 
;	A = 8 bit value of the converted digits
;	Y = Y' + the number of converted digits
;	converted digits clobbered
;
ihex8:
	sta STDIO_B0		; save digit count
	cmp #3			; if more than 2 digits
	bcs @is_two		; ... consume just the first two
	lsr			; set carry if one digit
	bcc @is_two
	jsr _ihex4		; convert the single digit
	rts
@is_two:
	jsr _ihex8		; convert both digits
	rts

;-----------------------------------------------------------------------
; _ihex8:
; Converts a two digit input string to its binary equivalent.
;
; On entry:
;	STDIO_W0 is a pointer to the input buffer
;	Y is the offset into the buffer 
; On return:
;	A = converted value
;	Y = Y' + 2
; 	converted input characters clobbered
;
_ihex8:
		phx
		; convert first digit
		jsr _ihex4
		; shift result into upper nibble
		asl
		asl
		asl
		asl
		tax			; X = result of first digit
		jsr _ihex4
		; convert second digit
		dey
		sta (STDIO_W0),y	; store result of second digit
		txa			; A = result of first digit
		ora (STDIO_W0),y	; merge result of second digit
		iny
		plx
		rts

;-----------------------------------------------------------------------
; _ihex4:
; Converts a 4-bit hexadecimal input character to its binary equivalent.
;
; On entry:
;	STDIO_W0 is a pointer to the input buffer
;	Y is the offset in the buffer of the character to convert
;
; On return:
;	A = converted value
;	Y = Y' + 1
_ihex4:
		lda (STDIO_W0),y
		iny
		cmp #'9'+1
		bcc @num_digit
		and #$df		; convert to upper case
		sec
		sbc #7			; A now in [$3A..$3F]
@num_digit:
		sec
		sbc #'0'		; A now in [0..15]
		rts


;-----------------------------------------------------------------------
; phex16:
; Prints a 16-bit value as four hexadecimal digits
;
; On entry:
;	AX contains the value to be printed
;
phex16:
		pha
		jsr phex8		; print the MSB
		txa
		jsr phex8		; print the MSB
		pla
		rts


;-----------------------------------------------------------------------
; phex8:
; Displays an 8-bit value as two hexadecimal digits
;
; On entry:
;	A contains the value to be displayed
;
phex8:
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
		jsr cputc		; display hex digit
		rts


