		.include "ascii.h.s"
		.include "stdio.h.s"
		.include "hex.h.s"
		.include "registers.h.s"

		.segment "ZEROPAGE"
_paragraph_index:
		.res 2
_paragraph_count:
		.res 2
_peek_buf:
		.res 16

		.segment "CODE"

;-----------------------------------------------------------------------
; peek:
; Peek at memory using a typical hexadecimal dump output.
; On entry:
;	w1 = pointer to start of memory range (inclusive)
;	w2 = pointer to end of memory range (exclusive)
;
		.global peek
peek:
		; set w0 to the highest address that is less than or
		; equal to w1 and is divisble by 16
		lda w1
		and #$f0
		sta w0
		lda w1+1
		sta w0+1
	
		; set w3 to the lowest address that is greater than or 
		; equal to w2 and is divisible by 16
		lda w2+1
		sta w3+1		; copy MSB
		lda w2
		sta w3			; copy LSB
		and #$0f
		beq @compute_count	; go if LSB is divisible by 16
		lda w3			; recover LSB
		and #$f0		; A = LSB - LSB mod 16
		clc
		adc #$10		; round up
		sta w3
		bcc @compute_count
		inc w3+1		; propagate carry
	
		; compute number of paragraphs to dump
		; w3 - w0 is the number of bytes rounded up to the nearest paragraph
		; divide it by 16 to get paragraph count
@compute_count:
		sec
		lda w3
		sbc w0
		sta _paragraph_count	; LSB of byte count
		lda w3+1
		sbc w0+1
		sta _paragraph_count+1	; MSB of byte count
		; divide by 16 
		lsr _paragraph_count+1
		ror _paragraph_count
		lsr _paragraph_count+1
		ror _paragraph_count
		lsr _paragraph_count+1
		ror _paragraph_count
		lsr _paragraph_count+1
		ror _paragraph_count

		; if the count ends up zero, we really want $1000 paragraphs (64K)
		lda _paragraph_count+1
		bne @no_trunc_count
		lda _paragraph_count
		bne @no_trunc_count
		lda #$10
		sta _paragraph_count+1
@no_trunc_count:

		; first paragraph is zero
		stz _paragraph_index
		stz _paragraph_index+1

@loop:
		stz b0
		lda #16
		sta b1

		jsr _is_first_paragraph
		bne @not_first
		lda w1
		and #$0f
		sta b0
@not_first:
		jsr _is_last_paragraph
		bne @not_last
		lda w2
		and #$0f
		bne @no_fixup
		lda #$10
@no_fixup:
		sta b1
@not_last:
		jsr _peek_paragraph
		jsr _next_paragraph
		bne @loop
		rts

_is_first_paragraph:
		lda _paragraph_index
		bne @done
		lda _paragraph_index+1
@done:
		rts

_is_last_paragraph:
		ldx _paragraph_count
		lda _paragraph_count+1
		ldx _paragraph_index
		lda _paragraph_index+1
		sec
		lda _paragraph_count
		sbc _paragraph_index
		sta w3
		lda _paragraph_count+1
		sbc _paragraph_index+1
		sta w3+1
		bne @done
		lda w3
		cmp #1
@done:
		rts

_is_done:
		lda _paragraph_count
		bne @done
		lda _paragraph_count+1
@done:
		rts


_next_paragraph:
		inc _paragraph_index
		bne @update_w0
		inc _paragraph_index+1
@update_w0:
		clc
		lda w0
		adc #$10
		sta w0
		bne @check_end
		inc w0+1
@check_end:
		sec
		lda _paragraph_count
		sbc _paragraph_index
		bne @done
		lda _paragraph_count+1
		sbc _paragraph_index+1
@done:
		rts

_peek_paragraph:
		lda w0+1
		jsr phex8		; print address MSB in hex
		lda w0
		jsr phex8		; print address LSB in hex
		lda #':'
		jsr cputc		; print colon
		lda #SPC
		jsr cputc		; print space
		ldy #0			; start of paragraph
@peek_hex:
		cpy b0			; compare to begin inset
		bcc @skip_hex		; skip if before begin inset
		cpy b1			; compare to end inset
		bcs @skip_hex		; skip if on/after end inset
		lda (w0),y		; fetch the byte
		sta _peek_buf,y		; save in zero page buffer
		jsr phex8		; print byte in hex
		lda #SPC		; for trailing space
		bra @next_hex
@skip_hex:
		lda #SPC
		jsr cputc		; print blank instead of digit
		jsr cputc		; print blank instead digit	
@next_hex:
		jsr cputc		; print trailiing space
		iny
		cpy #8			; halfway point?
		bne @no_space_hex	; not halfway
		jsr cputc		; print extra trailing space
@no_space_hex:			
		cpy #16			; end of paragraph?
		bne @peek_hex		; not end
		jsr cputc		; extra space before ASCII
		ldy #0			; start paragraph again
@peek_asc:
		cpy b0			; compare to begin inset
		bcc @skip_asc		; go if before begin inset
		cpy b1			; compare to end inset
		bcs @skip_asc		; go if on/after end inset
		lda _peek_buf,y		; fetch byte to print from buffer
		jsr _pasc8		; print ASCII for byte
		bra @next_asc		
@skip_asc:
		lda #SPC		; print blank instead of ASCII for byte
		jsr cputc
@next_asc:
		iny
		cpy #8			; halfway point
		bne @no_space_asc	; not halfway
		lda #SPC
		jsr cputc		; print extra trailing space
@no_space_asc:			
		cpy #16			; end of paragraph
		bne @peek_asc		; not at end
		lda #LF
		jsr cputc		; print newline
	
		rts

;-----------------------------------------------------------------------
; peek_one:
; Peek at a single address. The intended use case for this is peeking
; at an I/O device.
;
; On entry:
;	w1 = pointer to the memory location to peek
;
		.global peek_one
peek_one:
		lda (w1)		; fetch the byte to peek
		tax			; preserve it so we only fetch once
		jsr phex8		; show the hexdecimal value
		lda #SPC
		jsr cputc		; print a space
		txa			; recover the fetched byte
		jsr _pasc8		; show the ASCII value
		lda #LF
		jsr cputc		; print a newline
		rts


;-----------------------------------------------------------------------
; _pasc8:
; Displays the ASCII representation of an 8-bit value.
;
_pasc8:
		; is it an ASCII control character [0..0x31]?
		cmp #SPC
		bcc @put_dot
		; is it in the range [0x7f..0x80]?
		cmp #DEL
		bcs @put_dot
		; it's an ordinary printable ASCII character
		jsr cputc
		rts
@put_dot:
		; display a dot instead of the actual value
		lda #'.'
		jsr cputc
		rts

