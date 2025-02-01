
		.include "acia.h.s"
		.include "ports.h.s"


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

acia_reset:
                lda #ACIA_RESET
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
