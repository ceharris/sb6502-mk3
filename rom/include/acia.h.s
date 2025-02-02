	.ifndef ACIA_H
		ACIA_H = 1

; If ACIA_ISR_INCLUDED is non-zero, the library will include the ISR function.

	.ifndef ACIA_ISR_INCLUDED
		ACIA_ISR_INCLUDED := 0
	.endif

; When the ISR is included, these variables are used to specify the location
; of the ring buffer and assocaited pointers. The ring buffer is assumed to be 
; 256 bytes in length.
        .ifdef ACIA_ISR_INCLUDED
        .ifndef ACIA_RING
                ACIA_RING = $200        ; address of the ring buffer
        .endif
        .ifndef ACIA_HEAD
                ACIA_HEAD = $fe	        ; address of the head index pointer
        .endif
        .ifndef ACIA_TAIL
                ACIA_TAIL = $ff		; address of the tail index pointer
        .endif
        .endif


                ACIA_TDRE =  %00000010
                ACIA_DIV16 = %00000001
                ACIA_RESET = %00000011
                ACIA_8N1  = %00010100
                ACIA_RIE = %10000000

                ACIA_NOT_RTS = %01000000

	.if !ACIA_ISR_INCLUDED
                ACIA_CONFIG = ACIA_DIV16 | ACIA_8N1
	.else
                ACIA_CONFIG = ACIA_DIV16 | ACIA_8N1 | ACIA_RIE
		ACIA_RING_SIZE = $0100          ; changing this alone won't be sufficient
                ACIA_HIGH_WATER = ACIA_RING_SIZE - 16
                ACIA_LOW_WATER = 8
	.endif

	.macro ACIA_ASSERT_RTS
                lda #(ACIA_CONFIG & ~ACIA_NOT_RTS)
                sta ACIA_CTRL
	.endmacro

	.macro ACIA_WITHDRAW_RTS
                lda #(ACIA_CONFIG | ACIA_NOT_RTS)
                sta ACIA_CTRL
	.endmacro


		.global acia_init
		.global acia_shutdown
		.global acia_getc
		.global acia_putc
		.global acia_isr
	
	
	.endif