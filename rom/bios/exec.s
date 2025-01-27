
		.include "ansi.h.s"
		.include "ascii.h.s"
		.include "conf.h.s"
		.include "exec.h.s"
		.include "ports.h.s"
		.include "registers.h.s"
		.include "stdio.h.s"

		IPL_SIGNATURE = $FFF0

		.segment "PROGTAB"
progtab:
		; Program 0: Monitor 
		.byte $E	; slot
		.byte $80	; bank
		; Program 1: BASIC
		.byte $C	; slot
		.byte $81	; bank


		.segment "RODATA"
id_message:
		ansi_home
		ansi_erase_display
		.byte "SB6502 Mark 3", LF, LF
		.byte BEL
		.byte NUL

		.segment "CODE"

;-----------------------------------------------------------------------
; ipl:
; Initial program load. This routine puts the hardware into a known
; configuration with the MMU enabled, and then executes the monitor.
;
	.proc ipl
		sei			; inhibit interrupts
		cld			; clear decimal mode
		ldx #$ff		
		txs			; initialize stack

		; disable the MMU
		lda CONF_REG		; fetch config register
		and #<~CONF_MMUE	; clear the MMUE bit
		sta CONF_REG		; store config register

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
		
		stz w0			; base LSB for source is zero
		lda #$F0		; base MSB for source is $F0
		sta w0+1		
		stz w1			; base LSB for target is zero
		lda #$E0		; base MSB for target is $E0
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
		ldy #$E0		; interrupt vector memory offset in I/O page
		ldx #16			; 16 bytes to copy
@copy_ivec:
		lda (w0),y
		sta (w1),y
		iny
		dex
		bne @copy_ivec

		; We might have state at offsets $F0..F9 in the target RAM so we skip it
		ldy #$FA		; machine vector memory offset in I/O page
		ldx #6			; 6 bytes to copy
@copy_mvec:
		lda (w0),y
		sta (w1),y
		iny
		dex
		bne @copy_mvec

		; now memory in banks $87 and $F is (mostly) identical
		; swap out ROM in slot $F for RAM
		lda #$F			; bank $F
		sta MMU_SLOTF		; write to MMU bank register for slot $F

		; put RAM in slot $E
		dec a			; bank $E
		sta MMU_SLOTE		; write to MMU bank register for slot $E

		; initialize the serial console
		jsr acia_init
		cli			; allow interrupts

		; check for warm start
		lda #<PROG_MAGIC
		cmp IPL_SIGNATURE
		bne @cold_start
		lda #>PROG_MAGIC
		cmp IPL_SIGNATURE+1
		beq @warm_start

	@cold_start:
		; print startup message to console
		ldiw0 id_message
		jsr cputs

		; set the IPL signature
		lda #<PROG_MAGIC
		sta IPL_SIGNATURE
		lda #>PROG_MAGIC
		sta IPL_SIGNATURE+1

	@warm_start:
		; go launch the monitor
		lda #0
		
		; !!!!! FALLS THROUGH TO pexec !!!!!
	
	.endproc

;-----------------------------------------------------------------------
; pexec:
; Executes a stored program.
; 
; On entry:
;	A = program number (as given in progtab)
;
; On entry to the new program:
;	A, Y, X, w0, b0 clobbered
;
	.proc pexec
		; map program number to first slot and bank to map
		asl			; two bytes per table entry
		tax			; use as an index
		lda progtab,x		
		tay			; Y = first slot number
		lda progtab+1,x		; A = first bank number

		; map first bank into slot
		sta MMU_BASE,y		

		; put starting address for the slot in w0
		stz w0
		tya
		asl
		asl
		asl
		asl
		sta w0+1

		; check for magic word
		ldy #0
		lda #<PROG_MAGIC
		cmp (w0),y
		bne @err_magic
		iny
		lda #>PROG_MAGIC
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
		jsr cputc
		dex
		bne @err_loop
@halt:
		bra @halt
	.endproc