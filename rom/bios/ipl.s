
		.include "acia.h.s"
		.include "ascii.h.s"
		.include "conf.h.s"
		.include "exec.h.s"
		.include "ports.h.s"
		.include "registers.h.s"

		.segment "CODE"
		.export ipl

	.proc ipl
		sei			; inhibit interrupts
		cld			; clear decimal mode
		ldx #$ff		
		txs			; initialize stack

		; map banks $0..$D into slots $0..$D
		ldx #14			; map 16 banks
		ldy #0			; start at slot 0, bank 0
	@next_bank:
		tya			; bank number is the slot number
		sta MMU_BASE,y		; write to MMU bank register for slot (Y)
		iny			; next strop
		dex	
		bne @next_bank		; go if more slots to map

		; map bank $F into slot $E temporarily
		lda #$F			; bank $F
		sta MMU_SLOTE		; write to MMU bank register for slot E

		; map bank $87 into slot $F temporarily
		lda #$87		; bank $87
		sta MMU_SLOTF		; write to MMU bank register for slot E

		; enable the MMU
		lda CONF_REG		; fetch config register
		ora #CONF_MMUE		; set the MMUE bit
		sta CONF_REG		; store config register
		
		; copy $F000..FEFF (mapped to ROM bank $87)
		; down to $E000..EEFF (mapped to RAM bank $F)
		; we skip page at $FF00 because that's the I/O space
		
		lda #0			; base LSB for source and target is zero
		sta w0
		sta w1
		lda #$F0		; base MSB for source
		sta w0+1		
		lda #$E0		; base MSB for target
		sta w1+1	
		ldx #15			; 1 bank - 1 page = 15 x 256-byte pages
@copy_byte:
		lda (w0),y		; fetch byte from source
		sta (w1),y		; store byte to target
		iny
		bne @copy_byte		; go if more bytes in page

		inc w0+1		; next page of source
		inc w1+1		; next page of target
		dex
		bne @copy_byte		; go if more pages

		; $FFE0..FFFF is memory for vectors; copy them to RAM
		; Note that w0 and w1 are already positioned correctly
		ldy #$E0		; vector memory offset in I/O page
		ldx #32			; 32 bytes to copy
@copy_vec:
		lda (w0),y
		sta (w1),y
		iny
		dex
		bne @copy_vec

		; now memory in banks $87 and $F is identical
		; swap out ROM in slot $F for RAM
		lda #$F			; bank $F
		sta MMU_SLOTF		; write to MMU bank register for slot $F

		; put RAM in slot $E
		dec a			; bank $E
		sta MMU_SLOTE		; write to MMU bank register for slot $E

		jsr acia_init
		cli			; allow interrupts

		lda #$81		; load program bank $81
		ldy #$C			; map into slot $C
		jmp exec
	.endproc