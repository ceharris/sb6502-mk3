

		.org $400
ticks:
		.byte 0
		.byte 0
		.byte 0
		.byte 0		

DDDD:
		.byte 0
		.byte 0
HH:
		.byte 0
MM:
		.byte 0
SS:
		.byte 0
CC:
		.byte 0

		.org $500
timer_isr:
		inc ticks
		bne _time
		inc ticks+1
		bne _time
		inc ticks+2
		bne _time
		inc ticks+3
		bne _time
_time:
		sed
		clc
		lda CC
		adc #1
		sta CC
		bcc _done
		lda SS
		adc #0
		sta SS
		cmp #$60
		bne _done
		stz SS
		sec
		lda MM
		adc #0
		sta MM
		cmp #$60
		bne _done
		stz MM
		sec
		lda HH
		adc #0
		sta HH
		cmp #$24
		bne _done
		stz HH
		sec
		lda DDDD+1
		adc #0
		sta DDDD+1
		bcc _done		
		lda DDDD
		adc #0
		sta DDDD
_done:
		cld
		rti					


CR13 = $FF80
CR2 = $FF81
TIMER_COUNT = 18432
T2_LSB = 5
T2_MSB = 4

		.org $580
init:
		lda #<timer_isr
		sta $FFEE
		lda #>timer_isr
		sta $FFEF

		lda #>TIMER_COUNT
		sta T2_MSB
		lda #<TIMER_COUNT
		sta T2_LSB
		lda #$2
		sta CR13
		lda #$43
		sta CR2
		lda #$2
		sta CR13

		rts

		
