		.include "ascii.h.s"
		.include "registers.h.s"
;
; On entry:
;   	w0 contains the input string
;	Y is the offset into the input

		.global poke
		.global hex2bin
		.global is_hex
poke:
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
