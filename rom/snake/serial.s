                
                .include "ports.h.s"
                .include "state.h.s"
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
                ply                
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
                beq ser_flush::do_flush
                ply
                rts

        .endproc

ser_putci:
                lda ACIA_CTRL
                and #ACIA_TDRE
                beq ser_putci
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
; Puts a "wide" tring into the output buffer -- i.e. a string in which
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
