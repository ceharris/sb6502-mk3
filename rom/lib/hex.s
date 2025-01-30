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
;	A = number of hexadecimal digits found at the start of the 
;           input string
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
		plx
		rts


;-----------------------------------------------------------------------
; ihex8:
; Converts an 8-bit hexadecimal input string to its binary equivalent.
;
; On entry:
;	STDIO_W0 is a pointer to the input buffer
;	Y is the offset into the buffer 
; On return:
;	A = converted value
;	Y = Y' + 2
; 	converted input characters clobbered
;
ihex8:
		phx
		; convert first digit
		jsr ihex4
		; shift result into upper nibble
		asl
		asl
		asl
		asl
		tax			; X = result of first digit
		jsr ihex4
		; convert second digit
		dey
		sta (STDIO_W0),y	; store result of second digit
		txa			; A = result of first digit
		ora (STDIO_W0),y	; merge result of second digit
		iny
		plx
		rts


;-----------------------------------------------------------------------
; ihex4:
; Converts a 4-bit hexadecimal input character to its binary equivalent.
;
; On entry:
;	STDIO_W0 is a pointer to the input buffer
;	Y is the offset in the buffer of the character to convert
;
; On return:
;	A = converted value
;	Y = Y' + 1
ihex4:
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
		jsr phex4		; display upper nibble in hex
		pla			; recover input value
		jsr phex4		; display lower nibble in hex
		rts	


;-----------------------------------------------------------------------
; phex4:
; Displays a 4-bit value as a hexadecimal digit.
;
; On entry:
; 	Lower 4-bits of A contain the value to be displayed
;
phex4:
		and #$f			; isolate lower nibble
		clc	
		adc #'0'		; A now in ['0'..)
		cmp #'9' + 1
		bcc @no_adjust		; go if A in ['0'..'9']
		clc
		adc #7 + $20		; A now in ['a'..'f']
@no_adjust:
		jsr cputc		; display hex digit
		rts


