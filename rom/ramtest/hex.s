		.include "acia.h.s"
		.include "hex.h.s"

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
		adc #7			; A now in ['A'..'F']
@no_adjust:
		jsr acia_putc		; display hex digit
		rts


