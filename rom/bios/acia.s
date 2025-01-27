
		.include "ports.h.s"
		.include "acia.h.s"

                ACIA_TDRE =  %00000010
                ACIA_DIV16 = %00000001
                ACIA_RESET = %00000011
                ACIA_8N1  = %00010100
                ACIA_RIE = %10000000

                ACIA_NOT_RTS = %01000000

                ACIA_CONFIG = ACIA_DIV16 | ACIA_8N1 | ACIA_RIE

		ACIA_RING_SIZE = $0100

                ACIA_HIGH_WATER = ACIA_RING_SIZE - 16
                ACIA_LOW_WATER = 8

		.segment "ZEROPAGE"
acia_head:
		.res 1
acia_tail:	
		.res 1

		.segment "ACIA"
acia_ring:
		.res ACIA_RING_SIZE

		.segment "CODE"


;-----------------------------------------------------------------------
; acia_init:
; Initializes the ACIA hardware and ring buffer for input.
;
	.proc acia_init
		
		; initialize the ring buffer
		stz acia_head
		stz acia_tail

		; initialize the ACIA hardware
		lda #ACIA_RESET
		sta ACIA_CTRL
		lda #ACIA_CONFIG
		sta ACIA_CTRL

		rts
	.endproc


;-----------------------------------------------------------------------
; acia_putc:
; Writes a character to the console serial port.
;
; On entry:
;       A = the character to send
;
        .proc acia_putc
                pha                     ; save the character to send
@await_tdre:
                lda ACIA_CTRL           ; fetch status register
                and #ACIA_TDRE          ; isolate TDRE flag
                beq @await_tdre         ; wait if TDRE flag not set
                pla                     ; recover character to send
                sta ACIA_DATA           ; write the character
                rts
        .endproc


;-----------------------------------------------------------------------
; acia_getc:
; Reads the next input character from the console serial port if one
; is available.
;
; On return:
;       carry set => A is the next input character
;       carry clear => no character is available (A clobbered)
;
        .proc acia_getc
                sei                     ; disable interrupts
                lda acia_head           ; get head index
                cmp acia_tail           ; compare to tail index
                bne @char_waiting       ; go if at least one character
                clc                     ; indicate none available
                cli                     ; enable interrupts
                rts
@char_waiting:
                phx
                tax                     ; X = head index
                lda acia_ring,x         ; fetch next character fron ring
                inx                     ; next head index
                stx acia_head           ; store new head index
                plx
                pha                     ; preserve input character

                ; how many characters are in the ring?
                sec
                lda acia_tail
                sbc acia_head

                cmp #ACIA_LOW_WATER     ; at the low water mark?
                bne @no_rts_change      ; nope

                ; assert RTS signal
                lda #(ACIA_CONFIG & ~ACIA_NOT_RTS)
                sta ACIA_CTRL
@no_rts_change:
                cli                     ; enable interrupts
                pla                     ; recover input character
                sec                     ; indicate character available
                rts
        .endproc


;-----------------------------------------------------------------------
; acia_waitc:
; Reads the next input character from the console serial port. Waits
; until a character is available.
;
; On return:
;       A is the input character
;
        .proc acia_waitc
                jsr acia_getc
                bcc acia_waitc          ; keep waiting if none available
                rts
        .endproc


;-----------------------------------------------------------------------
; acia_isr:
; Handle the interrupt request for the ACIA.
;
        .proc acia_isr
                pha
@next_char:
                lda ACIA_CTRL           ; fetch status register
                ror                     ; shift RDRF flag into carry
                bcs @read_char          ; go if character waiting
                pla
                rti
@read_char:
                phx
                ldx acia_tail           ; fetch tail index for ring buffer
                lda ACIA_DATA           ; fetch the input character
                sta acia_ring,x         ; store input character in the ring
                inx                     ; next ring index
                stx acia_tail           ; store the new tail index
                plx

                ; how many characters are in the ring?
                sec
                lda acia_tail
                sbc acia_head

                cmp #ACIA_HIGH_WATER    ; at the high water mark?
                bne @next_char          ; nope

                ; deassert RTS signal
                lda #(ACIA_CONFIG | ACIA_NOT_RTS)
                sta ACIA_CTRL
                bra @next_char
        
	.endproc
