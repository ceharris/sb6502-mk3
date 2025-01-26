		.include ports.h.s

LF		.equ $a
CR		.equ $d
SPC		.equ $20
MMUE		.equ $80

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
motd:
		lda message,x
		beq begin
		jsr cputc
		inx
		bne motd
begin:
		jsr dump_mmu
		jsr config_mmu
		jsr dump_mmu
		lda CONF_REG
		ora #MMUE
		sta CONF_REG
echo:
		jsr cgetc
		jsr cputc
		cmp #CR
		bne echo
		lda #LF
		jsr cputc
		bra echo

done:
		bra done


config_mmu:
		ldx #0
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
	        .byte "SB6502 Mk3 MMU Test"
	        .byte CR, LF, 0

		.rend

		.include vectors.h.s
