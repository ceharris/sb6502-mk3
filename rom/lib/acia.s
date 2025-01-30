
		.include "acia.h.s"
		.include "ports.h.s"

; If ACIA_ISR_INCLUDED is non-zero, the library will include the ISR function.
; ACIA_ISR_INCLUDED = 0

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


		.segment "CODE"


;-----------------------------------------------------------------------
; acia_init:
; Initializes the ACIA hardware and (optional) ring buffer.
;
acia_init:	
        .if ACIA_ISR_INCLUDED
		; initialize the ring buffer
		stz ACIA_HEAD
		stz ACIA_TAIL
        .endif
		
                ; initialize the ACIA hardware
		lda #ACIA_RESET
		sta ACIA_CTRL
		lda #ACIA_CONFIG
		sta ACIA_CTRL

		rts


;-----------------------------------------------------------------------
; acia_putc:
; Writes a character to the console serial port.
;
; On entry:
;       A = the character to send
;
acia_putc:
                pha                     ; save the character to send
@await_tdre:
                lda ACIA_CTRL           ; fetch status register
                and #ACIA_TDRE          ; isolate TDRE flag
                beq @await_tdre         ; wait if TDRE flag not set
                pla                     ; recover character to send
                sta ACIA_DATA           ; write the character
                rts


;-----------------------------------------------------------------------
; acia_getc:
; Reads the next input character from the console serial port if one
; is available.
;
; On return:
;       carry set => A is the next input character
;       carry clear => no character is available (A clobbered)
;
acia_getc:        
        .if !ACIA_ISR_INCLUDED
                lda ACIA_CTRL
                ror                     ; put RDRF flag into carry
                bcc @none               ; go if no character waiting
                lda ACIA_DATA           ; read the character
@none:
                rts
        .else
                sei                     ; disable interrupts
                lda ACIA_HEAD           ; get head index
                cmp ACIA_TAIL           ; compare to tail index
                bne @char_waiting       ; go if at least one character
                clc                     ; indicate none available
                cli                     ; enable interrupts
                rts
@char_waiting:
                phx
                tax                     ; X = head index
                lda ACIA_RING,x         ; fetch next character fron ring
                inx                     ; next head index
                stx ACIA_HEAD           ; store new head index
                plx
                pha                     ; preserve input character

                ; how many characters are in the ring?
                sec
                lda ACIA_TAIL
                sbc ACIA_HEAD

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
        .endif


;-----------------------------------------------------------------------
; acia_isr:
; Handle the interrupt request for the ACIA.
;
        .if ACIA_ISR_INCLUDED

acia_isr:
                pha
@next_char:
                lda ACIA_CTRL           ; fetch status register
                ror                     ; shift RDRF flag into carry
                bcs @read_char          ; go if character waiting
                pla
                rti
@read_char:
                phx
                ldx ACIA_TAIL           ; fetch tail index for ring buffer
                lda ACIA_DATA           ; fetch the input character
                sta ACIA_RING,x         ; store input character in the ring
                inx                     ; next ring index
                stx ACIA_TAIL           ; store the new tail index
                plx

                ; how many characters are in the ring?
                sec
                lda ACIA_TAIL
                sbc ACIA_HEAD

                cmp #ACIA_HIGH_WATER    ; at the high water mark?
                bne @next_char          ; nope

                ; deassert RTS signal
                lda #(ACIA_CONFIG | ACIA_NOT_RTS)
                sta ACIA_CTRL
                bra @next_char
        
        .endif
