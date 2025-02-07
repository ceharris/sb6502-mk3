                
                .include "ports.h.s"
                .include "state.h.s"
                .include "serial.h.s"

                ACIA_RDRF = %00000001
		ACIA_TDRE =  %00000010
                ACIA_DIV16 = %00000001
                ACIA_RESET = %00000011
                ACIA_8N1  = %00010100
                ACIA_RIE = %10000000

                ACIA_CONFIG = ACIA_DIV16 | ACIA_8N1 | ACIA_RIE


                .segment "BSS"
in_ring:
                .align 256
                .res 256
out_buffer:
                .align 256
                .res 256

                .segment "ZEROPAGE"
in_head:
                .res 1
in_tail:
                .res 1
out_tail:
                .res 1


                .segment "CODE"

;-----------------------------------------------------------------------
; ser_init:
; Initialize serial communications interface.
;
ser_init:                
                ; reset the ACIA
                lda #ACIA_RESET
                sta ACIA_CTRL
                
                ; configure the ACIA
                lda #ACIA_CONFIG
                sta ACIA_CTRL
                
                ; zero the buffer pointers
                stz in_head
                stz in_tail
                stz out_tail
                
                rts

;-----------------------------------------------------------------------
; ser_isr:
; Handles the ACIA received data interrupt.
;
ser_isr: 
                pha
@next_char:
                lda ACIA_CTRL           ; fetch status register
                lsr                     ; shift RDRF flag into carry
                bcs @read_char          ; go if character waiting
                pla
                rti
@read_char:
                phx
                ldx in_tail             ; fetch tail index for ring buffer
                lda ACIA_DATA           ; fetch the input character
                sta in_ring,x           ; store input character in the ring
                inx                     ; next ring index
                stx in_tail             ; store the new tail index
                plx
                bra @next_char          ; try to get more


;-----------------------------------------------------------------------
; ser_flush:
; Flushes all characters waiting in the output buffer to the interface
; hardware.
;
ser_flush:
                phy
                ldy out_tail
                bne do_flush
                ply
                rts

                ; on entry here, Y must contain the current 
                ; value of the buffer's tail index pointer
do_flush:
                ; use X as the buffer index
                phx
                ldx #0          
@await_tdre:
                ; wait for ACIA to signal TDRE
                lda ACIA_CTRL
                and #ACIA_TDRE
                beq @await_tdre
                
                ; send the next character
                lda out_buffer,x
                sta ACIA_DATA
                
                ; update buffer index and counter
                inx
                dey
                bne @await_tdre

                ; zero the tail index pointer
                stz out_tail 

                plx
                ply                
                rts


;-----------------------------------------------------------------------
; ser_putc:
; Puts a character into the output buffer. If the buffer becomes full
; as a result, it is immediately flushed.
; 
; On entry:
;       A = character to put
;
ser_putc:
                phy
                ldy out_tail
                sta out_buffer,y
                iny
                sty out_tail
                beq do_flush
                ply
                rts


;-----------------------------------------------------------------------
; ser_putci:
; Sends a character to the serial output immediately, bypassing the 
; buffer.
; 
; On entry:
;       A = character to put
;
ser_putci:
                pha
                lda ACIA_CTRL
                and #ACIA_TDRE
                beq ser_putci
                pla
                sta ACIA_DATA
                rts
 

;-----------------------------------------------------------------------
; ser_puts:
; Puts a string into the output buffer. The buffer will be flushed as
; needed to accommodate the length of the string.
; 
; On entry:
;       W = pointer to the null-terminated string
;
        .proc ser_puts
                phy
                ldy #0
@next:
                lda (W),y
                beq @done
                jsr ser_putc
                iny
                bra @next
@done:
                ply
                rts
        .endproc


;-----------------------------------------------------------------------
; ser_putsw:
; Puts a "wide" string into the output buffer -- i.e. a string in which
; every pair of characters will have an intervening space. The buffer 
; will be flushed as needed to accommodate the doubled length of the 
; string.
; 
; On entry:
;       W = pointer to the null-terminated string
;
        .proc ser_putsw
                phy
                ldy #0
                lda (W),y
                beq @done
@next:
                jsr ser_putc
                iny
                lda (W),y
                beq @done
                lda #' '
                jsr ser_putc
                lda (W),y
                bra @next
@done:
                ply
                rts
        .endproc


;-----------------------------------------------------------------------
; ser_putsc:
; Puts a string into the output buffer consisting a repeated character. 
; The buffer will be flushed as needed to accommodate the length of the 
; string.
; 
; On entry:
;       A = character to repeat
;       X = number of times to repeat character (A)
;
; On return
;       B clobbered
;
        .proc ser_putsc
                sta B
@next:
                lda B
                jsr ser_putc
                dex
                bne @next
                rts
        .endproc


;-----------------------------------------------------------------------
; ser_getc:
; Gets a character from the serial input if one is available.
;
; On return:
;       A contains an input character iff carry set
;       X clobbered
;
ser_getc:
                ldx in_head             ; get head index
                cpx in_tail             ; compare to tail index
                bne @char_waiting       ; go if at least one character
                clc                     ; no character
                rts
@char_waiting:
                lda in_ring,x           ; fetch next character from ring
                inx                     ; next head index
                stx in_head             ; store new head index
                sec                     ; character available
                rts

;-----------------------------------------------------------------------
; ser_getcp:
; Gets a character from the serial input if one is available, pausing
; for a short period of time to allow for an expected character to
; arrive.
;
; On return:
;       A contains an input character iff carry set
;       X clobbered
;

ser_getcp:
                ldx #$20                ; delay counter
@loop:
                lda in_head             ; fetch head pointer
                cmp in_tail             ; compare to tail
                bne @char_waiting       ; go if at least one char
                dex
                bne @loop               ; go if still in delay
                clc                     ; no character
                rts
@char_waiting:
                tax                     ; X = head pointer
                lda in_ring,x           ; fetch character from buffer
                inx                     ; head pointer++
                stx in_head             ; save new head pointer
                sec                     ; character received
                rts