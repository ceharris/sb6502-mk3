
		.include "prng.h.s"
		.include "state.h.s"

		.segment "ZEROPAGE"
state:
		.res 5


		.segment "CODE"

;-----------------------------------------------------------------------
; rnd_zero:
; Seeds the psuedo random number sequence with zero.
;
; On return: 
;	A = zero
;
rnd_zero:
		phy
		lda #0
		ldy #0
@loop:
		sta state,y
		iny
		cpy #5
		bne @loop
		ply
		rts


;-----------------------------------------------------------------------
; rnd_seed:
; Seeds the psuedo random number sequence.
;
; On entry:
;	W = address of five bytes to be used as the seed
;
; On return:
; 	A clobbered
;
rnd_seed:
		phy
		ldy #0
@loop:
		lda (W),y
		sta state,y
		iny
		cpy #5
		bne @loop
		ply
		rts

;-----------------------------------------------------------------------
; rnd_range:
; Gets a psuedo-random number in the range [0..A-1]
;
rnd_range:
		sta B
		jsr rnd_next
@check:
		cmp B
		bcs @reduce
		rts
@reduce:
		sec
		sbc B
		bra @check


;-----------------------------------------------------------------------
; rnd_next:
; Gets the next 8-bit value from the sequence.
; Credit: https://github.com/Arlet/pseudo-random-number-generator/
;
; On return:
; 	A = psuedo-random value
;
rnd_next:		
		clc
		lda #$41
		adc state+0
		sta state+0
		adc state+1
		sta state+1
		adc state+2
		sta state+2
		adc state+3
		sta state+3
		adc state+4
		asl
		adc state+3
		sta state+4
		eor state+2
		rts