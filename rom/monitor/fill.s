		.include "registers.h.s"
		.global fill
fill:		
		tw1w0			;put starting address in w0
		; make the w2 endpoint inclusive by decrementing
		ldy #0
		lda w2		
		sec
		sbc #1
		sta w2
		bcs fill_again
		dec w2+1
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
