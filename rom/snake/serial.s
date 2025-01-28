                
                .include "ports.h.s"
                .include "serial.h.s"

                ACIA_RDRF = %00000001
		ACIA_TDRE =  %00000010
                ACIA_DIV16 = %00000001
                ACIA_RESET = %00000011
                ACIA_8N1  = %00010100

                ACIA_CONFIG = ACIA_DIV16 | ACIA_8N1


                .segment "BSS"
ser_buffer:
                .align 256
                .res 256


                .segment "ZEROPAGE"
ser_tail:
                .res 1


                .segment "CODE"

;-----------------------------------------------------------------------
; ser_init:
; Initialize serial communications interface.
;
	.proc ser_init
                
                ; reset the ACIA
                lda #ACIA_RESET
                sta ACIA_CTRL
                
                ; configure the ACIA
                lda #ACIA_CONFIG
                sta ACIA_CTRL
                
                ; zero the buffer's tail pointer
                stz ser_tail
                
                rts
	.endproc


;-----------------------------------------------------------------------
; ser_flush:
; Flushes all characters waiting in the output buffer to the interface
; hardware.
;
        .proc ser_flush
                phy
                ldy ser_tail
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
                lda ser_buffer,x
                sta ACIA_DATA
                
                ; update buffer index and counter
                inx
                dey
                bne @await_tdre

                ; zero the tail index pointer
                stz ser_tail 

                plx                
                rts

        .endproc


;-----------------------------------------------------------------------
; ser_putc:
; Puts a character into the output buffer. If the buffer becomes full
; as a result, it is immediately flushed.
; 
; On entry:
;       A = character to put
;
        .proc ser_putc
                
                phy
                ldy ser_tail
                sta ser_buffer,y
                iny
                sty ser_tail
                bne @done
                jsr ser_flush::do_flush
@done:
                ply
                rts

        .endproc


