		.include ports.h.s

R0		.equ 0

BEL		.equ $7
LF		.equ $a
CR		.equ $d

		.org $0
		.rorg $8000

noop_isr:
		rti

acia_isr:
		pha
		lda ACIA_CTRL
		lsr
		bcc acia_isr90
acia_isr10:
		lda ACIA_CTRL
		and #2
		beq acia_isr10
		lda ACIA_DATA
		sta ACIA_DATA
acia_isr90:
		pla
		rti


reset:
		cld
		ldx #$ff
		txs

		cli
		lda #3
		sta ACIA_CTRL
		lda #$95
		sta ACIA_CTRL

		ldx #0
motd:
		lda message,x
		beq start
		jsr cputc
		inx
		bne motd

start:
		bra start

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
	        .byte "SB6502 Mk3 IRQ Test"
	        .byte CR, LF, BEL, 0

		.rend

		.include vectors.h.s
