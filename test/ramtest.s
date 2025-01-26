		.include ports.h.s

BEL		.equ $7
LF		.equ $a
CR		.equ $d
SPC		.equ $20
MMUE		.equ $80

SLOT		.equ 1
SLOT_ADDR	.equ 4096*SLOT

		.org $0
		.rorg $8000

noop_isr:
		rti


		.macro pat_test, pg
		ldy #0
pat_test_05\@:
		lda #0
		sta SLOT_ADDR+256*\1,y
		cmp SLOT_ADDR+256*\1,y
		beq pat_test_10\@
		lda #\1
		jmp error
pat_test_10\@:
		lda #$55
		sta SLOT_ADDR + 256*\1,y
		cmp SLOT_ADDR + 256*\1,y
		beq pat_test_20\@
		lda #\1
		jmp error
pat_test_20\@:
		lda #$aa
		sta SLOT_ADDR + 256*\1,y
		cmp SLOT_ADDR + 256*\1,y
		beq pat_test_30\@
		lda #\1
		jmp error
pat_test_30\@:
		lda #$ff
		sta SLOT_ADDR + 256*\1,y
		cmp SLOT_ADDR + 256*\1,y
		beq pat_test_40\@
		lda #\1
		jmp error
pat_test_40\@:
		txa
		sta SLOT_ADDR + 256*\1,y
		iny
		bne pat_test_05\@
		.endmacro

		.macro bank_test,pg
		ldy #0
		txa
bank_test_10\@:
		cmp SLOT_ADDR + 256*\1,y
		beq bank_test_20\@
		lda #\1
		jmp error
bank_test_20\@:
		iny
		bne bank_test_10\@
		.endmacro

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

		ldx #0
pat_next:
		stx MMU_BASE+1
		txa
		jsr hex8
		lda #SPC
		jsr cputc
	
		pat_test 0
		pat_test 1
		pat_test 2
		pat_test 3
		pat_test 4
		pat_test 5
		pat_test 6
		pat_test 7
		pat_test 8
		pat_test 9
		pat_test 10
		pat_test 11
		pat_test 12
		pat_test 13
		pat_test 14
		pat_test 15

		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		inx
		cpx #$80
		beq pat_ok
		jmp pat_next
pat_ok:
		lda #'O'
		jsr cputc
		lda #'K'
		jsr cputc
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc

		ldx #1
bank_next:
		stx MMU_BASE+1
		txa
		jsr hex8
		lda #SPC
		jsr cputc

		bank_test 0
		bank_test 1
		bank_test 2
		bank_test 3
		bank_test 4
		bank_test 5
		bank_test 6
		bank_test 7
		bank_test 8
		bank_test 9
		bank_test 10
		bank_test 11
		bank_test 12
		bank_test 13
		bank_test 14
		bank_test 15

		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		inx
		cpx #$80
		beq bank_ok
		jmp bank_next

bank_ok:
		lda #'O'
		jsr cputc
		lda #'K'
		jsr cputc
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		jmp done
error:
		pha
		lda #'!'
		jsr cputc
		txa
		jsr hex8
		lda #SPC
		jsr cputc
		pla
		jsr hex8
		lda #SPC
		jsr cputc
		tya
		jsr hex8
		lda #CR
		jsr cputc
		lda #LF
		jsr cputc
		lda #BEL
		jsr cputc

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
	        .byte "SB6502 Memory Test"
	        .byte CR, LF, 0

		.rend

		.include vectors.h.s
