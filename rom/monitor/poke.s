		.include "ascii.h.s"
		.include "hex.h.s"
		.include "registers.h.s"
		.include "stdio.h.s"

;-----------------------------------------------------------------------------------
; poke:
; Poke a sequence of bytes into memory.
;
; On entry:
;   	w0 contains the input string
;	Y is the offset into the input

		.global poke
poke:
		; on entry (STDIO_W0),y is pointing at the '>'
		stz b0			; poke counter
		sty b1			; b1 = input offset
		stz b2			; b2 = poke offset
@poke_next:
@strip:
		iny
		lda (STDIO_W0),y
		beq @done		; done if end of input
		cmp #SPC
		beq @strip		; skip space
		cmp #TAB
		beq @strip		; skip tab
		cmp #'+'
		beq @incr		; increment w1 and exit
		sty b1			; b1 = input offset
		jsr hextok
		ldy b1			; Y = input offset
		cmp #0
		beq @error		; input isn't hex
		cmp #2+1
		bcs @error		; want just one or two hex chars
		jsr ihex8		; convert to binary
		sty b1			; b1 = input offset
		ldy b2			; Y = poke offset
		sta (w1),y		; poke it
		inc b0			; poke counter++
		iny			
		sty b2			; b2 = new poke offset
		ldy b1			; Y = input offset
		dey			; compensate
		bne @poke_next
@incr:
		iny
		lda (STDIO_W0),y
		bne @error		; error if not end of input
@incr_w1:
		clc
		lda w1
		adc b0			; add poke count to LSB
		sta w1			; save new LSB
		bcc @done		; go no if no carry out
		inc w1+1		; propagate carry to MSB
@done:
		rts
@error:
		lda #BEL
		jsr cputc
		rts

;-----------------------------------------------------------------------
; poke_one:
; Pokes a single byte at address w1. The intended use case for this
; is poking data into an I/O device.
;
		.global poke_one
poke_one:
		; on entry (STDIO_W0),y is pointing at the '>'
@strip:
		iny			; skip to next input char
		lda (STDIO_W0),y	; fetch input character
		cmp #SPC
		beq @strip
		cmp #TAB
		beq @strip
		sty b1			; save input pointer
		jsr hextok
		sta b0			; save count
		lda (STDIO_W0),y
		cmp #'+'
		bne @check_minus
		iny			; skip '+'
		bra @check_eol
@check_minus:
		cmp #'-'
		bne @check_eol		
		iny			; skip '-'
@check_eol:
		lda (STDIO_W0),y
		bne _error		; go if not at end of input
		ldy b1			; recover input pointer
		lda b0			; recover count
		beq @skip		; no hex chars entered
		jsr ihex8		; convert to binary
		sta (w1)		; poke it		
@skip:
		lda (STDIO_W0),y	; get terminating char
		cmp #'+'
		beq @incr_w1		; go increment w1
		cmp #'-'
		beq @decr_w1		; go decrement w1
		rts			; leave w1 as is
@incr_w1:
		inc w1
		bne @skip_w1_msb		
		inc w1+1
@skip_w1_msb:
		rts
@decr_w1:
		lda w1
		bne @decr_w1_lsb
		dec w1+1
@decr_w1_lsb:
		dec w1
		rts
_error:
		lda #BEL
		jsr cputc
		rts
