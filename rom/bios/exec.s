
		.include "acia.h.s"
		.include "ascii.h.s"
		.include "ports.h.s"
		.include "registers.h.s"

		MAGIC = $CE5B

		.export exec

;-----------------------------------------------------------------------
; exec:
; Executes a program stored in a memory bank.
;
; On entry:
;	A = initial bank number to map
;	Y = slot for bank (A)
;
; On return:
;	A, Y, X, w0, b0 clobbered
;
	.proc exec
		; map initial bank into slot
		sta MMU_BASE,y		

		; put starting address for the slot in w0
		lda #0
		sta w0
		tya
		asl
		asl
		asl
		asl
		sta w0+1

		; check for magic word
		ldy #0
		lda #<MAGIC
		cmp (w0),y
		bne @err_magic
		iny
		lda #>MAGIC
		cmp (w0),y
		bne @err_magic
		iny

		; get number of additional slots to map
		lda (w0),y
		beq @jump_in
		sta b0			; b0 = number of additional slots
@map_another:
		iny
		lda (w0),y		; A = slot number
		tax
		iny 
		lda (w0),y		; A = bank number
		sta MMU_BASE,x		; map slot (X) to bank (A)
		dec b0
		bne @map_another

		; jump to the specified starting address
@jump_in:
		iny
		lda (w0),y		; fetch LSB of jump address
		tax
		iny
		lda (w0),y		; fetch MSB of jump address
		stx w0			; store LSB of jump address
		sta w0+1		; store MSB of jump address
		jmp (w0)	
@err_magic:
		ldx #5
@err_loop:
		lda #BEL
		jsr acia_putc
		dex
		bne @err_loop
@halt:
		bra @halt
	.endproc