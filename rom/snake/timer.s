

		.include "timer.h.s"

	; Port mappings and constants for the MC6840 
	; programmable timer module

		PTM_BASE = $FF80
		PTM_WR_CTRL_1 = PTM_BASE+0
		PTM_WR_CTRL_2 = PTM_BASE+1
		PTM_WR_CTRL_3 = PTM_BASE+0
		PTM_WR_MSB_LATCH_1 = PTM_BASE+2
		PTM_WR_LSB_LATCH_1 = PTM_BASE+3
		PTM_WR_MSB_LATCH_2 = PTM_BASE+4
		PTM_WR_LSB_LATCH_2 = PTM_BASE+5
		PTM_WR_MSB_LATCH_3 = PTM_BASE+6
		PTM_WR_LSB_LATCH_3 = PTM_BASE+7

		PTM_RD_STATUS = PTM_BASE+1
		PTM_RD_MSB_COUNT_1 = PTM_BASE+2
		PTM_RD_LSB_COUNT_1 = PTM_BASE+3
		PTM_RD_MSB_COUNT_2 = PTM_BASE+4
		PTM_RD_LSB_COUNT_2 = PTM_BASE+5
		PTM_RD_MSB_COUNT_3 = PTM_BASE+6
		PTM_RD_LSB_COUNT_3 = PTM_BASE+7

		; Control register bit fields
		PTM_OUT_ENABLE = %10000000
		PTM_IRQ_ENABLE = %01000000
		PTM_CONTINUOUS_MODE_GWR = %00000000
		PTM_FREQUENCY_MODE_LT = %00001000
		PTM_COUNTINUOUS_MODE_GR = %00010000
		PTM_PULSE_WIDTH_MODE_LT = %00011000
		PTM_SINGLE_SHOT_MODE_GWR = %00100000
		PTM_FREQUENCY_MODE_GT = %00101000
		PTM_SINGLE_SHOT_MODE_GR = %00110000
		PTM_PULSE_WIDTH_MODE_GT = %00111000
		PTM_CLOCK_EXTERNAL = %00000000
		PTM_CLOCK_INTERNAL = %00000010
		PTM_ENABLE_CR3 = %00000000
		PTM_ENABLE_CR1 = %00000001
		PTM_COUNT_ALL = %00000000
		PTM_HOLD_ALL = %00000001
		PTM_NO_PRESCALE = %00000000
		PTM_PRESCALE = %00000001

		; Status register bit fields
		PTM_IRQ = %10000000
		PTM_IRQ_1 = %00000001
		PTM_IRQ_2 = %00000010
		PTM_IRQ_3 = %00000100

	; Tick period for 100 Hz clock, assuming 1.8432 MHz system clock
		TICK_PERIOD = 18432

		.segment "BSS"

	; This field is used to store a tick count as a  
	; 16-bit unsigned integer. With a tick pulse of 400 Hz
	; the counter, it rolls over after ~163 seconds
timer_ticks:
		.res 2

	; These fields are used to store the components of the
	; chronometer, in BCD format
chrono_second:				; seconds (0..59)
		.res 1
chrono_centisecond:			; centiseconds (0..99)
		.res 1

		.segment "CODE"

;-----------------------------------------------------------------------
; timer_start:
; Initializes the MC6840 programmable timer module and starts counting
; time at 100 Hz.
;
timer_start:
		stz timer_ticks+0
		stz timer_ticks+1
		stz chrono_second
		stz chrono_centisecond

	; Configure the timer period for timer 2, which we'll use 
	; for the tick counter and chronometer. Order here is
	; significant. The MSB is buffered by the MC6840 until the
	; LSB is latched, then both are transferred to the counter.
	;
		lda #>TICK_PERIOD	; MSB first
		sta PTM_WR_MSB_LATCH_2
		lda #<TICK_PERIOD	; LSB second
		sta PTM_WR_LSB_LATCH_2

	; Initialize all of the control registers.
	; Order here is significant. We write CR3, CR2, then CR1, as
	; described in documentation.

	; Configure timer 3 using defaults

		lda #0
		sta PTM_WR_CTRL_3	; write to CR3
		
	; Configure timer 2 to enable interrupts, use internal
	; clock source, and enable writes to CR1

		lda #(PTM_OUT_ENABLE|PTM_IRQ_ENABLE|PTM_CLOCK_INTERNAL|PTM_ENABLE_CR1)
		sta PTM_WR_CTRL_2	; write to CR2

	; Configure timer 1 using defaults

		lda #0
		sta PTM_WR_CTRL_1	; write to CR1


		rts


;-----------------------------------------------------------------------
; timer_stop:
; Stops counting time and disables interrupts from the MC6840.
;
timer_stop:
		lda #0
		sta PTM_WR_CTRL_2	; stop interrupts from timer 2
		rts


;-----------------------------------------------------------------------
; timer_isr:
; Interrupt service routine for the timer interrupt.
;
timer_isr:
		pha

	; read the status and then the counter to reset the 
	; interrupt flag as described in the documentation

		lda PTM_RD_STATUS
		lda PTM_RD_MSB_COUNT_2
		lda PTM_RD_LSB_COUNT_2

	; update the uint32 tick counter, propagating the carry
	; up through more significant bytes as needed
		inc timer_ticks
		bne @chrono
		inc timer_ticks+1
		bne @chrono
		inc timer_ticks+2
		bne @chrono
		inc timer_ticks+3
		bne @chrono

	; update the chronometer, propagating carry out from one
	; field to the next as needed
@chrono:
		sed			; fields are BCD

		; increment centiseconds
		sec
		lda chrono_centisecond
		adc #0
		sta chrono_centisecond		
		bcc @done

		; carry into seconds
		lda chrono_second
		adc #0			; carry set from previous add
		sta chrono_second

@done:
		pla
		rti					

