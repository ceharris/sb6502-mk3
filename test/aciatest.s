		.include ports.h.s

LF		.equ $a
CR		.equ $d

		.org $0
		.rorg $8000

noop_isr:
		rti


reset:
		cld
		ldx #$ff
		txs

		lda #3
		sta ACIA_CTRL
		lda #$15
		sta ACIA_CTRL

		ldx #0
loop1:
		lda message,x
		beq echo
		jsr cputc
		inx
		bne loop1

echo:
		jsr cgetc
		jsr cputc
		cmp #CR
		bne echo
		lda #LF
		jsr cputc
		bra echo

cgetc:
		lda ACIA_CTRL
		ror
		bcc cgetc
		lda ACIA_DATA
		rts

cputc:
		pha
cputc_10:
		lda ACIA_CTRL
		and #2
		beq cputc_10
		pla
		sta ACIA_DATA
		rts

message:
	        .byte "Hello, 6502!"
	        .byte $d, $a, 0

		.rend

		.include vectors.h.s
