	.include "../sound.h.s"

; Access functions for the AY-3-8910 programmable sound generator
;

YIN:
	jsr AYINT
	ldy FAC_LAST
	sty SND_ADDR
	ldy SND_DATA
	jmp SNGFLT

YOUT:
	jsr GETBYT
	phx
	jsr CHKCOM
	jsr GETBYT
	txa
	tay
	pla
	sta SND_ADDR
	stx SND_DATA
	rts

YPL:
	lda #0				; want the LSB
	pha
	beq YNOTE
YPH:
	lda #1				; want the MSB
	pha
YNOTE:
	jsr AYINT			; convert arg to signed int
	lda FAC_LAST			; A=note number
	and #$3f			; bound within range 0..63
	asl				; multiply by 2 for table index
	tay				; Y=table index
	pla				; get low/high indicator
	beq YLOW			; go if want LSB
	iny				; MSB is at next index
YLOW:
	lda snd_notes,y			; fetch from table
	tay				
	jmp SNGFLT			; return byte as an int
