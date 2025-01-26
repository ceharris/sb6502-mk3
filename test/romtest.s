		.include ports.h.s
		.include romtest.h.s

BEL		.equ $7
LF		.equ $a
CR		.equ $d
SPC		.equ $20
MMUE		.equ $80

SLOT		.equ 1
SLOT_ADDR	.equ 4096*SLOT


		.org 0
		fill_bank $80
		fill_bank $81
		fill_bank $82
		fill_bank $83
		fill_bank $84
		fill_bank $85
		fill_bank $86
	
		.org $7000
		.rorg $F000

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
motd:
		lda message,x
		beq begin
		jsr cputc
		inx
		bne motd
begin:
		jsr config_mmu
		jsr dump_mmu
		lda CONF_REG
		ora #MMUE
		sta CONF_REG

		ldx #$88
next_bank:
		txa
		jsr hex8
		lda #SPC
		jsr cputc
		stx MMU_BASE+SLOT
		txa
		ldy #0
next_byte:
		cmp SLOT_ADDR,y
		bne error
		iny
		bne next_byte
		inx
		beq ok
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		bra next_bank
ok:
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		lda #'O'
		jsr cputc
		lda #'K'
		jsr cputc
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		jsr done

error:
		lda #'!'
		jsr cputc
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
done:
		bra done


config_mmu:
		ldx #$80
config_mmu_ram:
		txa
		sta MMU_BASE,x
		inx
		cpx #8
		bne config_mmu_ram
		ldx #0
config_mmu_rom:
		txa
		ora #$80
		sta MMU_BASE+8,x
		inx
		cpx #8
		bne config_mmu_rom
		rts

dump_mmu:
		ldx #0
dump_mmu_10:
		lda MMU_BASE,x
		jsr hex8
		inx
		cpx #$10
		beq dump_mmu_20
		lda #SPC
		jsr cputc
		bra dump_mmu_10
dump_mmu_20:
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		rts

hex8:
		pha
		lsr
		lsr
		lsr
		lsr
		jsr hex4
		pla
		jsr hex4
		rts
hex4:
		and #$f
		clc
		adc #'0'
		cmp #'9'+1
		bcc hex4_10
		clc
		adc #7
hex4_10:
		jsr cputc
		rts


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
	        .byte CR, LF
		.byte "SB6502 ROM Bank Test"
	        .byte CR, LF, 0

		.rend
		.include vectors.h.s

		.org $8000
		fill_bank $88
		fill_bank $89
		fill_bank $8A
		fill_bank $8B
		fill_bank $8C
		fill_bank $8D
		fill_bank $8E
		fill_bank $8F
