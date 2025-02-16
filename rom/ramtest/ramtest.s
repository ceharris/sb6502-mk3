

		.include "acia.h.s"
		.include "ascii.h.s"
		.include "hex.h.s"		
		.include "prog.h.s"
		.include "ports.h.s"

		.segment "MAGIC"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $88
		.word ramtest


		BASE_ADDR = $1000

		.macro BACKSPACE num
		lda #BS
		.repeat num
		jsr acia_putc
		.endrepeat
		.endmacro


		.macro TEST_PAGE page_num
		.local Loop, Error, Done, Halt, Continue
		BACKSPACE 5
		txa			; A = bank number
		jsr phex8
		lda #>(BASE_ADDR + 256*page_num)
		jsr phex4
		lda #<(BASE_ADDR + 256*page_num)
		jsr phex8
		ldy #0
Loop:
		lda #$0
		sta BASE_ADDR + 256*page_num,y
		cmp BASE_ADDR + 256*page_num,y
		bne Error
		lda #$55
		sta BASE_ADDR + 256*page_num,y
		cmp BASE_ADDR + 256*page_num,y
		bne Error
		lda #$aa
		sta BASE_ADDR + 256*page_num,y
		cmp BASE_ADDR + 256*page_num,y
		bne Error
		lda #$ff
		sta BASE_ADDR + 256*page_num,y
		cmp BASE_ADDR + 256*page_num,y
		bne Error
		iny
		bne Loop
		bra Done
Error:
		lda #LF
		jsr acia_putc
		lda #'@'
		jsr acia_putc
		txa
		jsr phex8
		tya
		clc
		adc #<(BASE_ADDR + 256*page_num)
		tay
		adc #0
		jsr phex4
		tya
		jsr phex8
		lda #LF
		jsr acia_putc
Halt:
		jmp Halt
Done:
		jsr acia_getc
		bcc Continue
		jmp soft_reset
Continue:

		.endmacro

		.segment "CODE"

		.global ramtest
ramtest:
		jsr acia_init
ramtest_all:
		ldx #$0
ramtest_bank:
		jsr acia_getc
		bcc @do_bank	
@do_bank:
		stx MMU_SLOT1
		TEST_PAGE 0
		TEST_PAGE 1
		TEST_PAGE 2
		TEST_PAGE 3
		TEST_PAGE 4
		TEST_PAGE 5
		TEST_PAGE 6
		TEST_PAGE 7
		TEST_PAGE 8
		TEST_PAGE 9
		TEST_PAGE 10
		TEST_PAGE 11
		TEST_PAGE 12
		TEST_PAGE 13
		TEST_PAGE 14
		TEST_PAGE 15
		inx
		cpx #$80
		bne @next_bank
		lda #LF
		jsr acia_putc
		jmp ramtest_all
@next_bank:
		jmp ramtest_bank

		.include "reset.s"
